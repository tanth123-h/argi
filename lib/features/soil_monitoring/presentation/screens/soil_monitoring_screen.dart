import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/sensor_data.dart';
import 'package:chaona_app/features/soil_monitoring/presentation/providers/soil_live_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class SoilMonitoringScreen extends ConsumerWidget {
  const SoilMonitoringScreen({super.key});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final s = ref.watch(soilLiveProvider);
    final notifier = ref.read(soilLiveProvider.notifier);
    final latest = s.latest;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ตรวจสอบดิน',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              latest?.device ?? 'ESP32 sensor',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (latest?.rssi != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi,
                    size: 15,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${latest!.rssi} dBm',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Data Source Badge ────────────────────────────────────────────
          _DataSourceBadge(
            broker: s.broker,
            device: s.device,
            lastUpdate: latest?.receivedAt,
            onReconnect: notifier.reconnect,
          ),
          const SizedBox(height: 14),
          _MonitorModePanel(latest: latest),
          const SizedBox(height: 14),

          // ── Moisture Gauge ───────────────────────────────────────────────
          _MoistureGaugeCard(
            moisture: latest == null ? null : latest.soil.round(),
          ),
          const SizedBox(height: 14),

          // ── Temp / Humidity / pH ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'อุณหภูมิ',
                  value: latest == null
                      ? '--'
                      : latest.temperature.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'ความชื้นอากาศ',
                  value: latest == null
                      ? '--'
                      : latest.humidity.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.water_drop_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'pH ดิน',
                  value: latest == null ? '--' : latest.ph.toStringAsFixed(1),
                  unit: 'pH',
                  icon: Icons.science_rounded,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── NPK Bars ─────────────────────────────────────────────────────
          _NpkCard(n: latest?.n, p: latest?.p, k: latest?.k),
          const SizedBox(height: 14),

          // ── History Chart ────────────────────────────────────────────────
          _HistoryChartCard(
            history: s.history,
            metric: s.chartMetric,
            onMetricChanged: notifier.setChartMetric,
          ),

          // ── Modbus warning ───────────────────────────────────────────────
          if (latest != null && !latest.modbusOk) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เซ็นเซอร์ RS485 ไม่ตอบสนอง — ค่า pH และ NPK อาจไม่แม่นยำ กรุณาตรวจสอบสายไฟ',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _MonitorMode { handheld, stationary }

class _MonitorModePanel extends ConsumerStatefulWidget {
  final SensorData? latest;

  const _MonitorModePanel({required this.latest});

  @override
  ConsumerState<_MonitorModePanel> createState() => _MonitorModePanelState();
}

class _MonitorModePanelState extends ConsumerState<_MonitorModePanel> {
  final _client = Supabase.instance.client;
  _MonitorMode _mode = _MonitorMode.handheld;
  List<Map<String, dynamic>> _farms = const [];
  List<Map<String, dynamic>> _plots = const [];
  String? _farmId;
  String? _plotId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final rows = await _client
          .from('farms')
          .select('id,name')
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _farms = (rows as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _farmId = _farms.isEmpty ? null : _farms.first['id'] as String;
        _loading = false;
      });
      await _loadPlots();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlots() async {
    final farmId = _farmId;
    if (farmId == null) return;
    try {
      final rows = await _client
          .from('plots')
          .select('id,name')
          .eq('farm_id', farmId)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _plots = (rows as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _plotId = null;
      });
      _configureStationary();
    } catch (_) {
      if (mounted) setState(() => _plots = const []);
    }
  }

  void _configureStationary() {
    final farmId = _farmId;
    if (_mode != _MonitorMode.stationary) {
      ref.read(soilLiveProvider.notifier).disableStationaryPersistence();
    } else if (farmId != null) {
      ref
          .read(soilLiveProvider.notifier)
          .configureStationary(farmId: farmId, plotId: _plotId);
    }
  }

  Future<void> _saveHandheld() async {
    final farmId = _farmId;
    if (farmId == null) return;
    setState(() => _saving = true);
    try {
      Position? position;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}
      final result = await ref
          .read(soilLiveProvider.notifier)
          .saveHandheld(
            farmId: farmId,
            plotId: _plotId,
            deviceId: widget.latest?.device ?? 'handheld-01',
            latitude: position?.latitude,
            longitude: position?.longitude,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == SoilSaveResult.saved
                  ? 'บันทึกค่าจากเครื่องพกพาแล้ว'
                  : 'เก็บไว้ในเครื่องแล้ว ระบบจะส่งขึ้นเมื่ออินเทอร์เน็ตกลับมา',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'แหล่งตรวจวัด',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_MonitorMode>(
              segments: const [
                ButtonSegment(
                  value: _MonitorMode.handheld,
                  label: Text('เครื่องพกพา'),
                  icon: Icon(Icons.handyman_outlined),
                ),
                ButtonSegment(
                  value: _MonitorMode.stationary,
                  label: Text('สถานีประจำแปลง'),
                  icon: Icon(Icons.sensors_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() => _mode = value.first);
                _configureStationary();
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: 10),
            if (_loading)
              const LinearProgressIndicator()
            else if (_farms.isEmpty)
              const Text('สร้างฟาร์มก่อนเริ่มบันทึกค่าดิน')
            else ...[
              DropdownButtonFormField<String>(
                value: _farmId,
                decoration: const InputDecoration(labelText: 'ฟาร์ม'),
                items: _farms
                    .map(
                      (farm) => DropdownMenuItem<String>(
                        value: farm['id'] as String,
                        child: Text(farm['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _farmId = value);
                  _loadPlots();
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: _plots.any((plot) => plot['id'] == _plotId)
                    ? _plotId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'แปลงย่อย (ถ้ามี)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('ยังไม่ระบุแปลงย่อย'),
                  ),
                  ..._plots.map(
                    (plot) => DropdownMenuItem<String>(
                      value: plot['id'] as String,
                      child: Text(plot['name'] as String),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _plotId = value);
                  _configureStationary();
                },
              ),
              const SizedBox(height: 10),
              if (_mode == _MonitorMode.handheld)
                FilledButton.icon(
                  onPressed: widget.latest == null || _saving
                      ? null
                      : _saveHandheld,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('บันทึกค่าจุดนี้พร้อม GPS'),
                )
              else
                const Text(
                  'เมื่อเลือกฟาร์มแล้ว ค่าจาก MQTT จะถูกบันทึกอัตโนมัติ',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
            ],
            if (_farmId != null && widget.latest != null) ...[
              const SizedBox(height: 8),
              Text(
                'พร้อมบันทึกจาก ${widget.latest!.device}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data Source Badge
// ─────────────────────────────────────────────────────────────────────────────

class _DataSourceBadge extends StatelessWidget {
  final BrokerStatus broker;
  final DeviceStatus device;
  final DateTime? lastUpdate;
  final VoidCallback onReconnect;
  const _DataSourceBadge({
    required this.broker,
    required this.device,
    required this.lastUpdate,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext ctx) {
    final (color, icon, label) = switch ((broker, device)) {
      (BrokerStatus.connecting, _) => (
        Colors.orange,
        Icons.wifi_find_rounded,
        'กำลังเชื่อมต่อ broker…',
      ),
      (BrokerStatus.disconnected, _) => (
        Colors.red,
        Icons.wifi_off_rounded,
        'เชื่อมต่อไม่ได้ — กำลังลองใหม่',
      ),
      (BrokerStatus.connected, DeviceStatus.online) => (
        AppTheme.primaryGreen,
        Icons.sensors_rounded,
        'ESP32 ออนไลน์ ✓',
      ),
      (BrokerStatus.connected, DeviceStatus.offline) => (
        Colors.red,
        Icons.sensors_off_rounded,
        'ESP32 ออฟไลน์',
      ),
      (BrokerStatus.connected, DeviceStatus.unknown) => (
        Colors.orange,
        Icons.hourglass_top_rounded,
        'รอข้อมูลแรก…',
      ),
    };

    final time = lastUpdate == null
        ? '--'
        : DateFormat('HH:mm:ss').format(lastUpdate!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '📡 MQTT → broker.emqx.io  |  อัปเดต: $time',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Text(
                  '🔧 แหล่งข้อมูล: ESP32 + MAX485 + 7-in-1 NPK Modbus Sensor',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (broker == BrokerStatus.disconnected)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.red,
              onPressed: onReconnect,
              tooltip: 'เชื่อมต่อใหม่',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Moisture Gauge
// ─────────────────────────────────────────────────────────────────────────────

class _MoistureGaugeCard extends StatelessWidget {
  final int? moisture;
  const _MoistureGaugeCard({required this.moisture});

  Color _color(int v) {
    if (v < 30) return Colors.red.shade400;
    if (v < 55) return Colors.orange;
    return AppTheme.primaryGreen;
  }

  String _label(int v) {
    if (v < 30) return 'แห้งมาก — ควรรดน้ำ';
    if (v < 55) return 'ค่อนข้างแห้ง';
    if (v < 80) return 'ความชื้นเหมาะสม ✓';
    return 'ชื้นมากเกินไป';
  }

  @override
  Widget build(BuildContext ctx) {
    final v = moisture;
    final color = v == null ? AppTheme.textSecondary : _color(v);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (v ?? 0) / 100),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, t, __) => CustomPaint(
                  painter: _GaugePainter(progress: t, color: color),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          v == null ? '--' : '$v%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const Text(
                          'ความชื้น',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ความชื้นดิน',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v == null ? 'รอข้อมูล...' : _label(v),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '📍 วัดจาก: probe อนาล็อก (pin A0)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Text(
                    '⏱ อัปเดตทุก 2 วินาที',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    const start = 3 * pi / 4;
    const sweepMax = 3 * pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      start,
      sweepMax,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.grey.shade200,
    );
    canvas.drawArc(
      rect,
      start,
      sweepMax * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Metric Card
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NPK Card
// ─────────────────────────────────────────────────────────────────────────────

class _NpkCard extends StatelessWidget {
  final double? n, p, k;
  const _NpkCard({required this.n, required this.p, required this.k});

  static const _maxN = 200.0, _maxP = 100.0, _maxK = 250.0;

  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ค่าธาตุอาหารดิน  N-P-K',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RS485 Modbus',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryGreenDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _bar(ctx, 'N', 'ไนโตรเจน', n, _maxN, Colors.green.shade600),
            const SizedBox(height: 8),
            _bar(ctx, 'P', 'ฟอสฟอรัส', p, _maxP, Colors.amber.shade700),
            const SizedBox(height: 8),
            _bar(ctx, 'K', 'โพแทสเซียม', k, _maxK, Colors.blue.shade600),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext ctx,
    String sym,
    String name,
    double? val,
    double max,
    Color color,
  ) {
    final frac = ((val ?? 0) / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            sym,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: frac),
                  duration: const Duration(milliseconds: 500),
                  builder: (_, t, __) => LinearProgressIndicator(
                    value: t,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            val == null ? '--' : '${val.toStringAsFixed(1)} mg/kg',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  History Chart
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryChartCard extends StatelessWidget {
  final List<SensorData> history;
  final SoilChartMetric metric;
  final ValueChanged<SoilChartMetric> onMetricChanged;
  const _HistoryChartCard({
    required this.history,
    required this.metric,
    required this.onMetricChanged,
  });

  double _val(SensorData d) => switch (metric) {
    SoilChartMetric.soil => d.soil.toDouble(),
    SoilChartMetric.temperature => d.temperature,
    SoilChartMetric.humidity => d.humidity,
    SoilChartMetric.ph => d.ph,
  };

  (String, Color) get _meta => switch (metric) {
    SoilChartMetric.soil => ('ความชื้น %', AppTheme.primaryGreen),
    SoilChartMetric.temperature => ('อุณหภูมิ °C', Colors.orange),
    SoilChartMetric.humidity => ('ความชื้นอากาศ %', Colors.blue),
    SoilChartMetric.ph => ('pH', Colors.purple),
  };

  @override
  Widget build(BuildContext ctx) {
    final (label, color) = _meta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ประวัติ ${history.length} ค่าล่าสุด',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Text(
                  '⏱ real-time',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<SoilChartMetric>(
              segments: const [
                ButtonSegment(value: SoilChartMetric.soil, label: Text('ดิน')),
                ButtonSegment(
                  value: SoilChartMetric.temperature,
                  label: Text('อุณหภูมิ'),
                ),
                ButtonSegment(
                  value: SoilChartMetric.humidity,
                  label: Text('ชื้น'),
                ),
                ButtonSegment(value: SoilChartMetric.ph, label: Text('pH')),
              ],
              selected: {metric},
              onSelectionChanged: (s) => onMetricChanged(s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: history.length < 2
                  ? Center(
                      child: Text(
                        'กำลังเก็บข้อมูล...\nกราฟจะแสดงเมื่อได้รับข้อมูลสักครู่',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : _buildChart(color, label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Color color, String label) {
    final spots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), _val(history[i])),
    ];
    final vals = spots.map((s) => s.y);
    final minY = vals.reduce((a, b) => a < b ? a : b);
    final maxY = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.2).clamp(0.5, 10.0);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(v.abs() >= 10 ? 0 : 1),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (history.length / 4).clamp(1, 100).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= history.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('HH:mm:ss').format(history[i].receivedAt),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );
  }
}
