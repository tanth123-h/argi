import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/recommendations/data/source_catalog.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:chaona_app/features/weather_flood/data/weather_flood_service.dart';
import 'package:chaona_app/shared/widgets/mascot_companion.dart';

class FarmAnalysisScreen extends StatefulWidget {
  const FarmAnalysisScreen({super.key});

  @override
  State<FarmAnalysisScreen> createState() => _FarmAnalysisScreenState();
}

class _FarmAnalysisScreenState extends State<FarmAnalysisScreen> {
  final _client = Supabase.instance.client;
  final _gemini = GeminiService();
  final _weather = WeatherFloodService();
  String? _analysis;
  String? _error;
  bool _loading = true;
  List<Farm> _farms = const [];
  Farm? _selectedFarm;
  bool _overall = false;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  @override
  void dispose() {
    _weather.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      final rows = await _client
          .from('farms')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final farms = (rows as List)
          .map((row) => _farmFromRow(Map<String, dynamic>.from(row)))
          .where((farm) => farm.boundary.length >= 3)
          .toList();
      if (farms.isEmpty)
        throw StateError('ยังไม่มีฟาร์ม กรุณาวาดขอบเขตก่อน');
      if (mounted) {
        setState(() {
          _farms = farms;
          _selectedFarm ??= farms.first;
        });
      }
      final selected = _overall ? farms : <Farm>[_selectedFarm ?? farms.first];
      final contexts = <String>[];
      for (final farm in selected) {
        final readings = await SoilReadingRepository(_client).latestForFarm(farm.id);
        final reading = readings.isEmpty ? null : readings.first;
        final weather = await _weather.fetch(_center(farm), soilMoisture: (reading?['moisture'] as num?)?.toDouble());
        final soil = reading == null
            ? 'ยังไม่มีข้อมูลตรวจดินจาก ESP32'
            : 'ความชื้น=${reading['moisture'] ?? '-'}%, pH=${reading['ph'] ?? '-'}, EC=${reading['ec'] ?? '-'}, N=${reading['nitrogen'] ?? '-'}, P=${reading['phosphorus'] ?? '-'}, K=${reading['potassium'] ?? '-'}, เวลา=${reading['recorded_at'] ?? '-'}';
        contexts.add('ฟาร์ม=${farm.name}, พืช=${farm.cropType}, พื้นที่=${farm.areaRai.toStringAsFixed(2)} ไร่\nอากาศ=${weather.temperatureC.toStringAsFixed(1)} C, ฝนตอนนี้=${weather.rainMm.toStringAsFixed(1)} mm, โอกาสฝน 24 ชม.=${weather.rainProbability24h}%\nความเสี่ยงแล้ง=${weather.droughtStatus.name}, ความเสี่ยงน้ำท่วม=${weather.floodStatus.name}\nดิน: $soil');
      }
      final result = await _gemini.chat(
        message:
            _overall ? 'วิเคราะห์ภาพรวมทุกแปลงสำหรับเกษตรกรไทย เปรียบเทียบแปลงที่เสี่ยงที่สุดและจัดลำดับการลงพื้นที่: 1) สิ่งที่ควรทำวันนี้ 2) ความเสี่ยงดิน น้ำท่วม และแล้งแยกตามแปลง 3) ข้อมูลที่ยังขาด ห้ามสร้างตัวเลขใหม่ และห้ามอ้างว่าเป็นประกาศรัฐ' : 'วิเคราะห์แปลงที่เลือกสำหรับเกษตรกรไทย: 1) สิ่งที่ควรทำวันนี้ 2) ความเสี่ยงดิน น้ำท่วม และแล้ง 3) ข้อมูลที่ยังขาด 4) คำถามติดตามที่ควรถาม ห้ามสร้างตัวเลขใหม่ และห้ามอ้างว่าเป็นประกาศรัฐ ตอบเป็นภาษาไทยที่อ่านง่าย ใช้หัวข้อสั้นและรายการแนะนำ ไม่ใช้เครื่องหมาย Markdown เช่น ###, **, ---, หรือรหัสภาษาอังกฤษที่ผู้ใช้ไม่เข้าใจ',
        history: const [],
        farmContext: contexts.join('\n---\n'),
        soilContext: 'ข้อมูลจากเซนเซอร์และ API ของ ${_overall ? 'หลายแปลง' : 'แปลงที่เลือก'}',
      );
      if (mounted)
        setState(() {
          _farms = farms;
          _selectedFarm ??= farms.first;
          _analysis = result;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = GeminiService.readableError(error);
          _loading = false;
        });
    }
  }

  Farm _farmFromRow(Map<String, dynamic> row) {
    final points = row['polygon_coordinates'] is List
        ? (row['polygon_coordinates'] as List).whereType<Map>().map((point) {
            final value = Map<String, dynamic>.from(point);
            return LatLng(
              (value['lat'] as num).toDouble(),
              (value['lng'] as num).toDouble(),
            );
          }).toList()
        : const <LatLng>[];
    return Farm(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String? ?? 'ฟาร์ม',
      areaRai: ((row['size'] as num?)?.toDouble() ?? 0) / 1600,
      cropType: row['crop_type'] as String? ?? 'rice',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      location: row['location'] as String?,
      boundary: points,
    );
  }

  LatLng _center(Farm farm) {
    final lat =
        farm.boundary.map((p) => p.latitude).reduce((a, b) => a + b) /
        farm.boundary.length;
    final lng =
        farm.boundary.map((p) => p.longitude).reduce((a, b) => a + b) /
        farm.boundary.length;
    return LatLng(lat, lng);
  }

  String _cleanAnalysis(String input) {
    var text = input
        .replaceAll('noObservedFeature', 'ยังไม่พบพื้นที่น้ำท่วมจากข้อมูลที่ตรวจได้')
        .replaceAll('observedFeature', 'พบข้อมูลพื้นที่ที่ตรวจได้')
        .replaceAll('unavailable', 'ยังไม่มีข้อมูล')
        .replaceAll('watch', 'เฝ้าระวัง')
        .replaceAll('noData', 'ยังไม่มีข้อมูล');
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'\1');
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '• ');
    return text
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('วิเคราะห์ฟาร์มด้วย AI'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _runAnalysis,
          icon: const Icon(Icons.refresh),
          tooltip: 'วิเคราะห์ใหม่',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/mascot/mascot_soil.png', width: 58, height: 58, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'วิเคราะห์จากข้อมูลแปลง เซนเซอร์ ESP32 และสภาพอากาศล่าสุด',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_farms.isNotEmpty) ...[
          DropdownButtonFormField<Farm>(
            value: _selectedFarm,
            decoration: const InputDecoration(labelText: 'แปลงที่ต้องการวิเคราะห์'),
            items: _farms.map((farm) => DropdownMenuItem(value: farm, child: Text(farm.name))).toList(),
            onChanged: _loading ? null : (farm) => setState(() { _selectedFarm = farm; _overall = false; }),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('วิเคราะห์ภาพรวมทุกแปลง', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('เปรียบเทียบความเสี่ยงและจัดลำดับพื้นที่ที่ควรไปดูก่อน'),
            value: _overall,
            onChanged: _loading ? null : (value) => setState(() => _overall = value),
          ),
          const SizedBox(height: 8),
        ],
        if (_loading)
          const Padding(padding: EdgeInsets.all(32), child: MascotCompanion(mood: MascotMood.thinking, size: 110, message: 'กำลังอ่านข้อมูลทุกแปลง...')),
        if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_error!),
            ),
          ),
        if (_analysis != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SelectableText(
                _cleanAnalysis(_analysis!),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'แหล่งข้อมูลที่อนุญาตให้ใช้',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...SourceCatalog.all
              .take(6)
              .map(
                (source) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.verified_outlined,
                    color: AppTheme.primaryGreen,
                  ),
                  title: Text(source.title),
                  subtitle: SelectableText(
                    '${source.publisher}\n${source.url}',
                  ),
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'AI เป็นผู้ช่วยอธิบายข้อมูล ไม่ใช่ผู้วินิจฉัยหรือประกาศเตือนภัยแทนหน่วยงานรัฐ',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
