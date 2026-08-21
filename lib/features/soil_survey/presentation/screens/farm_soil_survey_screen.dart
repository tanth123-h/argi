import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/shared/widgets/reliable_satellite_layer.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/soil_monitoring/presentation/providers/soil_live_provider.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/sensor_data.dart';
import 'package:chaona_app/shared/widgets/mascot_loading.dart';
import '../../data/repositories/soil_survey_repository.dart';
import '../../domain/entities/sampling_point.dart';
import '../../domain/services/sampling_point_generator.dart';

class FarmSoilSurveyScreen extends ConsumerStatefulWidget {
  final Farm farm;
  const FarmSoilSurveyScreen({super.key, required this.farm});
  @override
  ConsumerState<FarmSoilSurveyScreen> createState() =>
      _FarmSoilSurveyScreenState();
}

class _FarmSoilSurveyScreenState extends ConsumerState<FarmSoilSurveyScreen> {
  late final SoilSurveyRepository _repository;
  late final List<SamplingPoint> _points;
  late final int _recommendedCount;
  String? _surveyId;
  String? _error;
  int _index = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = SoilSurveyRepository(Supabase.instance.client);
    _recommendedCount = SamplingPointGenerator.recommendedCount(widget.farm.areaRai);
    _points = SamplingPointGenerator().generate(
      plotId: 'farm-${widget.farm.id}',
      boundary: widget.farm.boundary,
      count: _recommendedCount,
    );
    _createSurvey();
  }

  Future<void> _createSurvey() async {
    if (_points.length != _recommendedCount) {
      setState(() {
        _loading = false;
        _error = 'ต้องมีขอบเขตแปลงอย่างน้อย 3 จุดก่อนเริ่มตรวจดิน';
      });
      return;
    }
    try {
      final survey = await _repository.createSurvey(
        farmId: widget.farm.id,
        points: _points,
      );
      if (mounted)
        setState(() {
          _surveyId = survey.id;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'สร้างรอบตรวจดินไม่สำเร็จ: $error';
        });
    }
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw StateError('กรุณาเปิดบริการตำแหน่งของโทรศัพท์');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw StateError('ต้องอนุญาตตำแหน่งเพื่อบันทึกจุดนี้');
    return Geolocator.getCurrentPosition();
  }

  Future<void> _save() async {
    final surveyId = _surveyId;
    final latest = ref.read(soilLiveProvider).latest;
    if (surveyId == null || _saving) return;
    if (latest == null) {
      setState(
        () => _error = 'ยังไม่พบค่าจาก ESP32 กรุณารอข้อมูลล่าสุดก่อนบันทึก',
      );
      return;
    }
    if (!latest.modbusOk) {
      setState(() => _error = 'ESP32 ออนไลน์แล้ว แต่ยังอ่านเซนเซอร์ NPK ไม่ได้ กรุณาต่อไฟให้เซนเซอร์และตรวจสาย RS485 ก่อนบันทึก');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final point = _points[_index];
      final position = await _getPosition();
      final result = await ref
          .read(soilLiveProvider.notifier)
          .saveHandheld(
            farmId: widget.farm.id,
            surveyId: surveyId,
            samplingPointId: point.id,
            deviceId: latest.device,
            latitude: position.latitude,
            longitude: position.longitude,
          );
      if (result == SoilSaveResult.queued) {
        throw StateError(
          'บันทึกไว้ในเครื่องแล้ว แต่ยังส่งขึ้นระบบไม่ได้ กรุณาต่ออินเทอร์เน็ตแล้วกดบันทึกจุดนี้อีกครั้ง',
        );
      }
      await _repository.updatePointStatus(
        surveyId: surveyId,
        samplingKey: point.id,
        status: SamplingPointStatus.sampled,
        sampledAt: DateTime.now(),
      );
      if (_index == _points.length - 1) {
        await _repository.completeSurvey(surveyId);
        if (mounted)
            ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ตรวจดินครบ ${_points.length} จุดแล้ว')));
      } else if (mounted) {
        setState(() => _index++);
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(soilLiveProvider).latest;
    final sensorReady = latest?.modbusOk == true;
    final setupError = _error != null && _surveyId == null;
    return Scaffold(
      appBar: AppBar(title: Text('ตรวจดิน ${widget.farm.name}')),
      body: _loading
          ? const MascotLoading(message: 'กำลังเตรียมจุดตรวจดิน...')
          : setupError
          ? _ErrorState(message: _error ?? 'ไม่ทราบสาเหตุ')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProgressCard(index: _index, total: _points.length, areaRai: widget.farm.areaRai),
                _SamplingMap(farm: widget.farm, points: _points, activeIndex: _index),
                const SizedBox(height: 16),
                _PointCard(
                  point: _points[_index],
                  index: _index,
                  total: _points.length,
                  latestDevice: latest?.device,
                  latest: latest,
                  saving: _saving,
                  onSave: !sensorReady || _saving ? null : _save,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                Text(
                  'วิธีนี้เป็นการคัดกรองภาคสนาม ไม่ใช่ผลแล็บ: ระบบแนะนำ ${_points.length} จุดตามขนาดพื้นที่เพื่อดูความต่างในแปลง แล้วใช้ผลแล็บยืนยันก่อนใส่ปุ๋ยครั้งใหญ่',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'แนวทางอ้างอิง: กรมพัฒนาที่ดินแนะนำเก็บตัวอย่างให้กระจายทั่วพื้นที่และแยกพื้นที่ที่มีสภาพต่างกัน',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primaryGreenDark),
                ),
              ],
            ),
    );
  }
}

class _SamplingMap extends StatelessWidget {
  final Farm farm;
  final List<SamplingPoint> points;
  final int activeIndex;
  const _SamplingMap({required this.farm, required this.points, required this.activeIndex});
  LatLng _center() => LatLng(farm.boundary.map((p) => p.latitude).reduce((a, b) => a + b) / farm.boundary.length, farm.boundary.map((p) => p.longitude).reduce((a, b) => a + b) / farm.boundary.length);
  @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 220, child: Stack(children: [
    FlutterMap(options: MapOptions(initialCenter: _center(), initialZoom: 16), children: [
      reliableSatelliteLayer(),
      PolygonLayer(polygons: [Polygon(points: farm.boundary, color: const Color(0x4430C58A), borderColor: Colors.white, borderStrokeWidth: 3)]),
      MarkerLayer(markers: [for (var i = 0; i < points.length; i++) Marker(point: LatLng(points[i].latitude, points[i].longitude), width: 38, height: 38, child: Container(decoration: BoxDecoration(color: i == activeIndex ? AppTheme.secondaryBrown : AppTheme.primaryGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))))]),
    ]),
    Positioned(left: 12, top: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(18)), child: Text('จุดตรวจ ${points.length} จุด • จุดสว่างคือจุดปัจจุบัน', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
  ])));
}

class _ProgressCard extends StatelessWidget {
  final int index;
  final int total;
  final double areaRai;
  const _ProgressCard({required this.index, required this.total, required this.areaRai});
  @override
  Widget build(BuildContext context) => Card(
    color: AppTheme.primaryGreenLight,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สำรวจดินทั้งแปลง • ${areaRai.toStringAsFixed(1)} ไร่',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (index + 1) / total),
          const SizedBox(height: 8),
          Text('${index + 1} จาก $total จุดที่ระบบแนะนำตามขนาดพื้นที่'),
        ],
      ),
    ),
  );
}

class _PointCard extends StatelessWidget {
  final SamplingPoint point;
  final int index;
  final int total;
  final String? latestDevice;
  final SensorData? latest;
  final bool saving;
  final VoidCallback? onSave;
  const _PointCard({
    required this.point,
    required this.index,
    required this.total,
    required this.latestDevice,
    required this.latest,
    required this.saving,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'จุดตรวจที่ ${index + 1}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'ละติจูด ${point.latitude.toStringAsFixed(6)}\nลองยืนใกล้จุดนี้ แล้วกดบันทึกค่าจาก ESP32',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.sensors_outlined,
                color: AppTheme.primaryGreenDark,
              ),
              const SizedBox(width: 8),
              Text(
                latestDevice == null
                    ? 'ยังไม่พบข้อมูลจาก ESP32'
                    : latest?.modbusOk == true
                    ? 'พร้อมอ่านค่าจาก $latestDevice'
                    : 'ESP32 ออนไลน์ แต่ยังอ่านค่า NPK ไม่ได้',
              ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ReadingChip(label: 'ความชื้น', value: '${latest!.moisture.toStringAsFixed(1)}%'),
              _ReadingChip(label: 'pH', value: latest!.ph.toStringAsFixed(2)),
              _ReadingChip(label: 'N', value: latest!.n.toStringAsFixed(1)),
              _ReadingChip(label: 'P', value: latest!.p.toStringAsFixed(1)),
              _ReadingChip(label: 'K', value: latest!.k.toStringAsFixed(1)),
            ]),
            const SizedBox(height: 8),
            Text('ค่าจาก ${latest!.device} • รับข้อมูล ${latest!.receivedAt.toLocal()}', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          const Text('วิธีวัดให้เทียบกันได้: เก็บเศษพืชออก ปักหัววัดลึกใกล้เคียงกัน รอค่าคงที่ และหลีกเลี่ยงจุดที่เพิ่งใส่ปุ๋ยหรือมีน้ำขัง', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed),
            label: Text(
              index == total - 1 ? 'บันทึกและสรุปผล' : 'บันทึกจุดนี้พร้อม GPS',
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReadingChip extends StatelessWidget {
  final String label; final String value;
  const _ReadingChip({required this.label, required this.value});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.primaryGreenLight, borderRadius: BorderRadius.circular(10)), child: Text('$label $value', style: const TextStyle(color: AppTheme.primaryGreenDark, fontWeight: FontWeight.w700, fontSize: 12)));
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('กลับ'),
          ),
        ],
      ),
    ),
  );
}
