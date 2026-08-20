import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/shared/widgets/reliable_satellite_layer.dart';
import 'package:chaona_app/features/ai_chat/data/services/gemini_service.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/farm_tools/domain/farm_alerts.dart';
import 'package:chaona_app/features/farm_tools/domain/farm_tools_calculators.dart';
import 'package:chaona_app/features/farm_tools/data/farm_operations_repository.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/device_calibration_repository.dart';
import 'package:chaona_app/features/weather_flood/data/weather_flood_service.dart';
import 'package:chaona_app/features/weather_flood/domain/entities/weather_flood_snapshot.dart';
import 'package:chaona_app/shared/widgets/mascot_loading.dart';

class FarmToolsScreen extends StatefulWidget {
  const FarmToolsScreen({super.key});
  @override
  State<FarmToolsScreen> createState() => _FarmToolsScreenState();
}

class _FarmToolsScreenState extends State<FarmToolsScreen> {
  final _client = Supabase.instance.client;
  final _picker = ImagePicker();
  final _gemini = GeminiService();
  late final FarmOperationsRepository _operations;
  final _eto = TextEditingController(text: '5');
  final _kc = TextEditingController(text: '1.05');
  final _rain = TextEditingController(text: '0');
  final _price = TextEditingController(text: '8.5');
  final _yield = TextEditingController(text: '0.5');
  final _cost = TextEditingController(text: '3500');
  List<Farm> _farms = const [];
  List<Map<String, dynamic>> _readings = const [];
  List<Map<String, dynamic>> _cycles = const [];
  List<Map<String, dynamic>> _actions = const [];
  bool _operationsReady = true;
  Farm? _farm;
  int _rainProbability = 0;
  double? _moisture;
  DateTime? _lastReading;
  Uint8List? _leaf;
  String? _disease;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _operations = FarmOperationsRepository(_client);
    _load();
  }

  @override
  void dispose() {
    for (final c in [_eto, _kc, _rain, _price, _yield, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      final rows = await _client
          .from('farms')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if ((rows as List).isEmpty)
        throw StateError('ยังไม่มีฟาร์ม กรุณาสร้างแปลงก่อน');
      final farms = (rows as List)
          .map((row) => _farmFromRow(Map<String, dynamic>.from(row)))
          .toList();
      final farm = farms.first;
      final readings = await SoilReadingRepository(
        _client,
      ).latestForFarm(farm.id);
      final reading = readings.isEmpty ? null : readings.first;
      final weather = await _weatherFor(farm, reading);
      await _loadOperations(farm.id);
      if (mounted)
        setState(() {
          _farms = farms;
          _farm = farm;
          _readings = readings.reversed.toList();
          _moisture = (reading?['moisture'] as num?)?.toDouble();
          _lastReading = DateTime.tryParse(
            reading?['recorded_at']?.toString() ?? '',
          );
          _rainProbability = weather?.rainProbability24h ?? 0;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Farm _farmFromRow(Map<String, dynamic> row) => Farm(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    name: row['name'] as String? ?? 'ฟาร์ม',
    areaRai: ((row['size'] as num?)?.toDouble() ?? 0) / 1600,
    cropType: row['crop_type'] as String? ?? 'rice',
    createdAt:
        DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    location: row['location'] as String?,
    boundary: row['polygon_coordinates'] is List
        ? (row['polygon_coordinates'] as List).whereType<Map>().map((p) {
            final v = Map<String, dynamic>.from(p);
            return LatLng(
              (v['lat'] as num).toDouble(),
              (v['lng'] as num).toDouble(),
            );
          }).toList()
        : const [],
  );
  LatLng _center(Farm f) {
    final lat =
        f.boundary.map((p) => p.latitude).reduce((a, b) => a + b) /
        f.boundary.length;
    final lng =
        f.boundary.map((p) => p.longitude).reduce((a, b) => a + b) /
        f.boundary.length;
    return LatLng(lat, lng);
  }

  Future<void> _selectFarm(Farm? farm) async {
    if (farm == null || farm.id == _farm?.id) return;
    setState(() {
      _farm = farm;
      _loading = true;
      _error = null;
    });
    try {
      final readings = await SoilReadingRepository(
        _client,
      ).latestForFarm(farm.id);
      final reading = readings.isEmpty ? null : readings.first;
      final weather = await _weatherFor(farm, reading);
      await _loadOperations(farm.id);
      if (mounted)
        setState(() {
          _readings = readings.reversed.toList();
          _moisture = (reading?['moisture'] as num?)?.toDouble();
          _lastReading = DateTime.tryParse(
            reading?['recorded_at']?.toString() ?? '',
          );
          _rainProbability = weather?.rainProbability24h ?? 0;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _loadOperations(String farmId) async {
    try {
      final values = await Future.wait([
        _operations.cycles(farmId),
        _operations.actions(farmId),
      ]);
      _cycles = values[0];
      _actions = values[1];
      _operationsReady = true;
    } catch (_) {
      _cycles = const [];
      _actions = const [];
      _operationsReady = false;
    }
  }

  Future<WeatherFloodSnapshot?> _weatherFor(
    Farm farm,
    Map<String, dynamic>? reading,
  ) async {
    if (farm.boundary.length < 3) return null;
    try {
      return await WeatherFloodService().fetch(
        _center(farm),
        soilMoisture: (reading?['moisture'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _addCycle() async {
    final farm = _farm;
    if (farm == null || !_operationsReady) return;
    final variety = TextEditingController();
    var plantedAt = DateTime.now();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('เพิ่มรอบเพาะปลูก'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: variety,
                decoration: const InputDecoration(labelText: 'พันธุ์พืช'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('วันที่ปลูก'),
                subtitle: Text(
                  '${plantedAt.day}/${plantedAt.month}/${plantedAt.year}',
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: dialogContext,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDate: plantedAt,
                  );
                  if (selected != null) setLocal(() => plantedAt = selected);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await _operations.createCycle(
        farmId: farm.id,
        cropType: farm.cropType,
        variety: variety.text,
        plantedAt: plantedAt,
      );
      await _loadOperations(farm.id);
      if (mounted) setState(() {});
    }
    variety.dispose();
  }

  Future<void> _addAction() async {
    final farm = _farm;
    if (farm == null || !_operationsReady) return;
    var type = 'watering';
    final note = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('บันทึกงานในแปลง'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'งานที่ทำ'),
                items: const [
                  DropdownMenuItem(value: 'watering', child: Text('ให้น้ำ')),
                  DropdownMenuItem(
                    value: 'fertilizing',
                    child: Text('ใส่ปุ๋ย'),
                  ),
                  DropdownMenuItem(
                    value: 'inspection',
                    child: Text('ตรวจแปลง'),
                  ),
                  DropdownMenuItem(
                    value: 'spraying',
                    child: Text('ป้องกันโรค/แมลง'),
                  ),
                  DropdownMenuItem(value: 'harvest', child: Text('เก็บเกี่ยว')),
                  DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                ],
                onChanged: (value) => setLocal(() => type = value ?? type),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await _operations.addAction(
        farmId: farm.id,
        cycleId: _activeCycle?['id'] as String?,
        actionType: type,
        note: note.text,
      );
      await _loadOperations(farm.id);
      if (mounted) setState(() {});
    }
    note.dispose();
  }

  Future<void> _calibrateDevice() async {
    final farm = _farm;
    final deviceId = _readings.isEmpty
        ? null
        : _readings.last['device_id']?.toString();
    if (farm == null || deviceId == null || deviceId.isEmpty) return;
    final moisture = TextEditingController(text: '0');
    final ph = TextEditingController(text: '0');
    final ec = TextEditingController(text: '1');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ปรับเทียบ $deviceId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(moisture, 'ชดเชยความชื้น (%)'),
            _field(ph, 'ชดเชย pH'),
            _field(ec, 'ตัวคูณ EC'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (save == true) {
      final multiplier = double.tryParse(ec.text) ?? 0;
      if (multiplier <= 0) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ตัวคูณ EC ต้องมากกว่า 0')),
          );
      } else {
        await DeviceCalibrationRepository(_client).save(
          farmId: farm.id,
          deviceId: deviceId,
          moistureOffset: double.tryParse(moisture.text) ?? 0,
          phOffset: double.tryParse(ph.text) ?? 0,
          ecMultiplier: multiplier,
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'บันทึกการปรับเทียบแล้ว ค่าครั้งถัดไปจะใช้การตั้งค่านี้',
              ),
            ),
          );
      }
    }
    moisture.dispose();
    ph.dispose();
    ec.dispose();
  }

  Future<void> _pickLeaf() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังรูป'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file == null || _farm == null) return;
    setState(() {
      _leaf = null;
      _disease = null;
    });
    final bytes = await file.readAsBytes();
    setState(() => _leaf = bytes);
    final extension = file.name.toLowerCase();
    final mimeType = extension.endsWith('.png')
        ? 'image/png'
        : extension.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    try {
      final result = await _gemini.analyzeLeafImage(
        cropType: _farm!.cropType,
        imageBytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) setState(() => _disease = result);
    } catch (e) {
      if (mounted) setState(() => _disease = GeminiService.readableError(e));
    }
  }

  Future<void> _exportReport() async {
    final farm = _farm;
    if (farm == null) return;
    final water = const FarmWaterCalculator().calculate(
      etoMmPerDay: double.tryParse(_eto.text) ?? 0,
      kc: double.tryParse(_kc.text) ?? 0,
      effectiveRainMm: double.tryParse(_rain.text) ?? 0,
      areaRai: farm.areaRai,
    );
    final economics = const FarmEconomics();
    final profit = economics.profit(
      yieldTonsPerRai: double.tryParse(_yield.text) ?? 0,
      areaRai: farm.areaRai,
      pricePerKg: double.tryParse(_price.text) ?? 0,
      costPerRai: double.tryParse(_cost.text) ?? 0,
    );
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final bold = await PdfGoogleFonts.notoSansThaiBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Chaona AI - รายงานวิเคราะห์ฟาร์ม',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'ฟาร์ม: ${farm.name} | พืช: ${farm.cropType} | พื้นที่: ${farm.areaRai.toStringAsFixed(2)} ไร่',
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'ความชื้นดินล่าสุด: ${_moisture?.toStringAsFixed(1) ?? '-'}%',
            ),
            pw.Text(
              'น้ำสุทธิที่คำนวณ: ${water.volumeM3PerDay.toStringAsFixed(2)} ลูกบาศก์เมตร/วัน',
            ),
            pw.Text('กำไรประมาณการ: ${profit.toStringAsFixed(0)} บาท'),
            pw.SizedBox(height: 20),
            pw.Text(
              'หมายเหตุ: ค่าเป็นการวัด/คำนวณจากข้อมูลที่มี ณ เวลาสร้างรายงาน ต้องตรวจสอบกับคำแนะนำเจ้าหน้าที่ในพื้นที่ก่อนตัดสินใจ',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'แหล่งอ้างอิง: FAO Crop Evapotranspiration, กรมวิชาการเกษตร, ThaiWater/GISTDA',
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'chaona-farm-report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: MascotLoading(message: 'กำลังเตรียมเครื่องมือสำหรับแปลง...'));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('เครื่องมือฟาร์ม')),
        body: Padding(padding: const EdgeInsets.all(18), child: Text(_error!)),
      );
    }
    final alerts = const FarmAlertRules().evaluate(
      moisture: _moisture,
      lastReading: _lastReading,
      rainProbability24h: _rainProbability,
    );
    final farm = _farm!;
    final water = const FarmWaterCalculator().calculate(
      etoMmPerDay: double.tryParse(_eto.text) ?? 0,
      kc: double.tryParse(_kc.text) ?? 0,
      effectiveRainMm: double.tryParse(_rain.text) ?? 0,
      areaRai: farm.areaRai,
    );
    final economics = const FarmEconomics();
    final profit = economics.profit(
      yieldTonsPerRai: double.tryParse(_yield.text) ?? 0,
      areaRai: farm.areaRai,
      pricePerKg: double.tryParse(_price.text) ?? 0,
      costPerRai: double.tryParse(_cost.text) ?? 0,
    );
    final children = <Widget>[
      Text(farm.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      if (alerts.isNotEmpty) ...[
        Text('การแจ้งเตือน', style: Theme.of(context).textTheme.titleLarge),
        for (final alert in alerts)
          Card(
            child: ListTile(
              leading: Icon(
                alert.urgent ? Icons.warning_amber : Icons.info_outline,
                color: alert.urgent ? Colors.red : Colors.orange,
              ),
              title: Text(alert.title),
              subtitle: Text(alert.detail),
            ),
          ),
      ],
      _section(context, 'กราฟประวัติดิน', _moistureChart()),
      _section(context, 'แผนที่จุดตรวจดิน', _soilMap(farm)),
      _section(
        context,
        'ปรับเทียบ ESP32',
        OutlinedButton.icon(
          onPressed: _readings.isEmpty ? null : _calibrateDevice,
          icon: const Icon(Icons.tune),
          label: Text(
            _readings.isEmpty
                ? 'ยังไม่มีอุปกรณ์ให้ปรับเทียบ'
                : 'ปรับเทียบ ${_readings.last['device_id']}',
          ),
        ),
      ),
      _section(
        context,
        'รอบเพาะปลูก',
        _operationsReady
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeCycle == null)
                    const Text('ยังไม่มีรอบเพาะปลูกที่กำลังใช้งาน')
                  else
                    Text(
                      '${_activeCycle!['variety'] ?? farm.cropType} • ปลูก ${_activeCycle!['planted_at']} • ${_activeCycle!['status']}',
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addCycle,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มรอบเพาะปลูก'),
                  ),
                ],
              )
            : const Text('ต้องรัน farm_operations_setup.sql ก่อน'),
      ),
      _section(
        context,
        'สมุดบันทึกแปลง',
        _operationsReady
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_actions.isEmpty)
                    const Text('ยังไม่มีประวัติงาน')
                  else
                    ..._actions
                        .take(5)
                        .map(
                          (action) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(
                              _actionName(action['action_type']?.toString()),
                            ),
                            subtitle: Text(
                              '${action['occurred_at']}\n${action['note'] ?? ''}',
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addAction,
                    icon: const Icon(Icons.add_task),
                    label: const Text('บันทึกงาน'),
                  ),
                ],
              )
            : const Text('ต้องรัน farm_operations_setup.sql ก่อน'),
      ),
      _section(
        context,
        'เครื่องคำนวณน้ำ ET₀ × Kc',
        Column(
          children: [
            _field(_eto, 'ET₀ (มม./วัน)'),
            _field(_kc, 'Kc ของระยะเติบโต'),
            _field(_rain, 'ฝนใช้ได้ (มม./วัน)'),
            Text(
              'ETc ${water.etcMmPerDay.toStringAsFixed(2)} มม./วัน • น้ำสุทธิ ${water.volumeM3PerDay.toStringAsFixed(2)} ลบ.ม./วัน',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      _section(
        context,
        'ต้นทุนและกำไร',
        Column(
          children: [
            _field(_yield, 'ผลผลิต (ตัน/ไร่)'),
            _field(_price, 'ราคาขาย (บาท/กก.)'),
            _field(_cost, 'ต้นทุน (บาท/ไร่)'),
            Text(
              'กำไรประมาณการ ${profit.toStringAsFixed(0)} บาท',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      _section(
        context,
        'วิเคราะห์โรคจากรูปใบ',
        Column(
          children: [
            OutlinedButton.icon(
              onPressed: _pickLeaf,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('ถ่ายรูป/เลือกรูปใบพืช'),
            ),
            if (_leaf != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.memory(_leaf!, height: 160),
              ),
            if (_disease != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(_disease!),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _exportReport,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('สร้างรายงาน PDF สำหรับการแข่งขัน'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('เครื่องมือฟาร์ม'),
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'รายงาน PDF',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_farms.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<Farm>(
                value: farm,
                decoration: const InputDecoration(labelText: 'ฟาร์มที่กำลังดู'),
                items: _farms
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: _selectFarm,
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _moistureChart() {
    final values = _readings
        .map((row) => (row['moisture'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (values.length < 2)
      return const Text('ต้องมีข้อมูล ESP32 อย่างน้อย 2 ครั้งจึงจะแสดงกราฟ');
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              color: AppTheme.primaryGreen,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? get _activeCycle {
    for (final cycle in _cycles) {
      if (cycle['status'] == 'active') return cycle;
    }
    return null;
  }

  Widget _soilMap(Farm farm) {
    if (farm.boundary.length < 3)
      return const Text('ฟาร์มนี้ยังไม่มีขอบเขตสำหรับแสดงแผนที่');
    final markers = <Marker>[];
    for (final reading in _readings) {
      final lat = (reading['latitude'] as num?)?.toDouble();
      final lng = (reading['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final moisture = (reading['moisture'] as num?)?.toDouble() ?? 0;
      final color = moisture < 20
          ? Colors.red
          : moisture < 30
          ? Colors.orange
          : const Color(0xFF2F7D58);
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                moisture.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          options: MapOptions(initialCenter: _center(farm), initialZoom: 16),
          children: [
            reliableSatelliteLayer(),
            PolygonLayer(
              polygons: [
                Polygon(
                  points: farm.boundary,
                  color: const Color(0x332F7D58),
                  borderColor: const Color(0xFF2F7D58),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
  String _actionName(String? value) => switch (value) {
    'watering' => 'ให้น้ำ',
    'fertilizing' => 'ใส่ปุ๋ย',
    'inspection' => 'ตรวจแปลง',
    'spraying' => 'ป้องกันโรค/แมลง',
    'harvest' => 'เก็บเกี่ยว',
    _ => 'งานอื่น',
  };
  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (_) => setState(() {}),
    ),
  );
}
