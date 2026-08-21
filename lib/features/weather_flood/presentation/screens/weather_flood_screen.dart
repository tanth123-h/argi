import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/weather_flood/data/weather_flood_service.dart';
import 'package:chaona_app/features/weather_flood/domain/entities/weather_flood_snapshot.dart';
import 'package:chaona_app/shared/widgets/reliable_satellite_layer.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:chaona_app/shared/widgets/mascot_loading.dart';

class WeatherFloodScreen extends StatefulWidget {
  const WeatherFloodScreen({super.key});
  @override
  State<WeatherFloodScreen> createState() => _WeatherFloodScreenState();
}

class _WeatherFloodScreenState extends State<WeatherFloodScreen> {
  final _client = Supabase.instance.client;
  final _service = WeatherFloodService();
  List<Farm> _farms = const [];
  Farm? _farm;
  WeatherFloodSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw StateError('กรุณาเข้าสู่ระบบก่อน');
      final rows = await _client
          .from('farms')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      _farms = (rows as List)
          .map((row) => _farmFromRow(Map<String, dynamic>.from(row)))
          .where((farm) => farm.boundary.length >= 3)
          .toList();
      if (_farms.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'ยังไม่มีฟาร์มที่มีขอบเขต กรุณาวาดขอบเขตฟาร์มก่อน';
        });
        return;
      }
      _farm = _farms.first;
      await _refresh();
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
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

  Future<void> _refresh() async {
    final farm = _farm;
    if (farm == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SoilReadingRepository(_client).latestForFarm(farm.id);
      final moisture = rows.isEmpty
          ? null
          : (rows.first['moisture'] as num?)?.toDouble();
      final value = await _service.fetch(_center(farm), soilMoisture: moisture);
      if (mounted)
        setState(() {
          _snapshot = value;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'โหลดสภาพอากาศไม่สำเร็จ: $error';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('สภาพอากาศและน้ำท่วม'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _refresh,
          tooltip: 'รีเฟรช',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        _hero(context),
        if (_farms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: DropdownButtonFormField<Farm>(
              value: _farm,
            decoration: const InputDecoration(labelText: 'เลือกฟาร์มเพื่อดูข้อมูล'),
              items: _farms.map((farm) => DropdownMenuItem(value: farm, child: Text(farm.name))).toList(),
              onChanged: (farm) {
                if (farm == null) return;
                setState(() { _farm = farm; _snapshot = null; });
                _refresh();
              },
            ),
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(28), child: MascotLoading(message: 'กำลังอ่านอากาศและภัยใกล้แปลง...')),
        if (_error != null) _ErrorCard(message: _error!),
        if (_snapshot != null) ...[
          _riskOverview(context, _snapshot!),
          if (_farm != null) _mapPanel(context, _farm!, _snapshot!),
          _WeatherCard(snapshot: _snapshot!),
          _ForecastCard(snapshot: _snapshot!),
          const SizedBox(height: 12),
          _FloodCard(snapshot: _snapshot!),
          const SizedBox(height: 12),
          _DroughtCard(snapshot: _snapshot!),
          const SizedBox(height: 12),
          _SourceCard(snapshot: _snapshot!),
        ],
        if (!_loading && _error == null && _snapshot == null && _farms.isEmpty)
          const _ErrorCard(message: 'กรุณาสร้างฟาร์มและวาดขอบเขตก่อน'),
      ],
    ),
  );

  Widget _hero(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0B7051), Color(0xFF27A979), Color(0xFF9BD96B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ภาพรวมความเสี่ยง', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('อากาศ น้ำท่วม และความชื้นในแปลงเดียว', style: TextStyle(color: Colors.white70)),
        ])),
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/images/mascot/mascot_weather.png', fit: BoxFit.contain))),
      ],
    ),
  );

  Widget _riskOverview(BuildContext context, WeatherFloodSnapshot s) {
    final floodColor = s.floodStatus == FloodStatus.observed ? Colors.red : AppTheme.primaryGreen;
    final droughtColor = s.droughtStatus == DroughtStatus.soilStress ? Colors.red : s.droughtStatus == DroughtStatus.unavailable ? Colors.orange : AppTheme.primaryGreen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Expanded(child: _RiskPill(icon: Icons.water_drop_outlined, label: 'น้ำท่วม', value: s.floodStatus == FloodStatus.observed ? 'พบข้อมูล' : 'ไม่พบสัญญาณ', color: floodColor)),
        const SizedBox(width: 10),
        Expanded(child: _RiskPill(icon: Icons.invert_colors_outlined, label: 'ขาดน้ำ', value: s.droughtStatus == DroughtStatus.unavailable ? 'รอวัดดิน' : s.droughtStatus == DroughtStatus.soilStress ? 'เสี่ยงสูง' : 'ปกติ', color: droughtColor)),
      ]),
    );
  }

  Widget _mapPanel(BuildContext context, Farm farm, WeatherFloodSnapshot s) {
    final center = _center(farm);
    final flood = s.floodStatus == FloodStatus.observed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(height: 245, child: Stack(children: [
          FlutterMap(options: MapOptions(initialCenter: center, initialZoom: 15.5), children: [
            reliableSatelliteLayer(),
            CircleLayer(circles: [CircleMarker(point: center, radius: 5000, useRadiusInMeter: true, color: (flood ? Colors.red : Colors.orange).withOpacity(.16), borderColor: (flood ? Colors.red : Colors.orange).withOpacity(.75), borderStrokeWidth: 2)]),
            PolygonLayer(polygons: [Polygon(points: farm.boundary, color: const Color(0x5530C58A), borderColor: Colors.white, borderStrokeWidth: 3)]),
            MarkerLayer(markers: [
              Marker(point: center, width: 44, height: 44, child: Container(decoration: BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.eco, color: Colors.white))),
              for (final point in s.floodPoints)
                Marker(point: point, width: 40, height: 40, child: Container(decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 21))),
            ]),
          ]),
          Positioned(left: 14, top: 14, child: _MapLabel(icon: Icons.satellite_alt, text: 'ภาพดาวเทียม')),
          Positioned(right: 14, bottom: 14, child: _MapLabel(icon: Icons.radio_button_checked, text: flood ? 'ตรวจพบข้อมูลในรัศมี 5 กม.' : 'รัศมีตรวจข้อมูล 5 กม.')),
        ])),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _RiskPill({required this.icon, required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(.25))), child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800))]))]));
}

class _MapLabel extends StatelessWidget {
  final IconData icon; final String text;
  const _MapLabel({required this.icon, required this.text});
  @override Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))])));
}

class _WeatherCard extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _WeatherCard({required this.snapshot});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สภาพอากาศตอนนี้',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.thermostat_outlined,
                size: 38,
                color: AppTheme.fieldClay,
              ),
              const SizedBox(width: 12),
              Text(
                '${snapshot.temperatureC.toStringAsFixed(1)} °C',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              Text(snapshot.weatherLabel),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ฝนขณะนี้ ${snapshot.rainMm.toStringAsFixed(1)} มม. • โอกาสฝนใน 24 ชม. สูงสุด ${snapshot.rainProbability24h}%',
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _MetricTile(label: 'โอกาสฝน 24 ชม.', value: '${snapshot.rainProbability24h}%', icon: Icons.umbrella_outlined, color: Colors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _WindTile(snapshot: snapshot)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: 'อัปเดตล่าสุด', value: _age(snapshot.fetchedAt), icon: Icons.schedule, color: AppTheme.fieldClay)),
          ]),
        ],
      ),
    ),
  );

  String _age(DateTime date) {
    final minutes = DateTime.now().difference(date.toLocal()).inMinutes;
    return minutes <= 1 ? 'เมื่อสักครู่' : '$minutes นาทีที่แล้ว';
  }
}

class _WindTile extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _WindTile({required this.snapshot});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.teal.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Transform.rotate(angle: snapshot.windDirectionDegrees * math.pi / 180, child: const Icon(Icons.navigation_rounded, color: Colors.teal, size: 22)),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${snapshot.windKmh.toStringAsFixed(0)} กม./ชม.', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w800)),
        Text('ทิศ ${snapshot.windDirection}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ])),
    ]),
  );
}

class _ForecastCard extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _ForecastCard({required this.snapshot});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: Row(children: [
            Icon(Icons.calendar_month_outlined, color: AppTheme.primaryGreenDark),
            SizedBox(width: 8),
            Expanded(child: Text('พยากรณ์ 7 วันสำหรับแปลงนี้', style: TextStyle(fontWeight: FontWeight.w800))),
            Icon(Icons.swipe_outlined, size: 18, color: AppTheme.textSecondary),
          ]),
        ),
        const SizedBox(height: 5),
        const Padding(padding: EdgeInsets.only(right: 16), child: Text('ใช้วางแผนให้น้ำ เลี่ยงฉีดพ่นก่อนฝน และเตรียมรับลมแรง', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.forecast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final day = snapshot.forecast[index];
              final today = index == 0;
              return Container(
                width: 108,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: today ? [const Color(0xFFE2F5E7), const Color(0xFFF8FCF5)] : [Colors.white, const Color(0xFFF4F7F2)]),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: today ? AppTheme.primaryGreen : const Color(0xFFE1E9E0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(today ? 'วันนี้' : '${day.date.day}/${day.date.month}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${day.maxC.toStringAsFixed(0)}° / ${day.minC.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Row(children: [const Icon(Icons.water_drop_outlined, size: 14, color: Colors.blue), const SizedBox(width: 3), Text('${day.rainProbability}%')]),
                  Row(children: [const Icon(Icons.air, size: 14, color: Colors.teal), const SizedBox(width: 3), Text('${day.windKmh.toStringAsFixed(0)}')]),
                ]),
              );
            },
          ),
        ),
      ]),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color;
  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))]))]));
}

class _FloodCard extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _FloodCard({required this.snapshot});
  @override
  Widget build(BuildContext context) {
    final observed = snapshot.floodStatus == FloodStatus.observed;
    final unavailable = snapshot.floodStatus == FloodStatus.unavailable;
    final color = observed
        ? Colors.red
        : unavailable
        ? Colors.orange
        : AppTheme.primaryGreen;
    final title = observed
        ? 'พบพื้นที่น้ำท่วมใกล้ฟาร์ม'
        : unavailable
        ? 'ข้อมูลน้ำท่วมไม่พร้อม'
        : 'ยังไม่พบพื้นที่น้ำท่วมในข้อมูลล่าสุด';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              observed
                  ? Icons.warning_amber_rounded
                  : Icons.water_drop_outlined,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(snapshot.floodDetail),
                  if (snapshot.floodPoints.isNotEmpty)
                    Text(
                      'หมุดสีแดงคือจุด/พื้นที่ที่ GISTDA ส่งกลับมา ไม่ใช่ขอบเขตน้ำท่วมที่วัดโดย ESP32',
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'ผลนี้ไม่แทนประกาศฉุกเฉินของหน่วยงานรัฐ',
                    style: TextStyle(fontSize: 12),
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

class _SourceCard extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _SourceCard({required this.snapshot});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('แหล่งข้อมูลและข้อจำกัด', style: TextStyle(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('ข้อมูลอากาศเป็นพยากรณ์จาก Open-Meteo ไม่ใช่การวัดจากสถานีในแปลงโดยตรง'),
    const SizedBox(height: 4),
    const Text('น้ำท่วมคือชั้นข้อมูลพื้นที่ที่พบจาก GISTDA ในรัศมีประมาณ 5 กม. ไม่ใช่คำเตือนฉุกเฉิน'),
    const SizedBox(height: 4),
    const Text('ภาวะขาดน้ำใช้หลายปัจจัยร่วมกัน: ความชื้นดินจาก ESP32, โอกาสฝน และพยากรณ์อากาศ จึงไม่ควรตัดสินจาก sensor ตัวเดียว'),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: [Chip(avatar: const Icon(Icons.cloud_outlined, size: 16), label: const Text('Open-Meteo')), Chip(avatar: const Icon(Icons.map_outlined, size: 16), label: const Text('GISTDA')), Chip(avatar: const Icon(Icons.verified_outlined, size: 16), label: const Text('ข้อมูลมีข้อจำกัด'))]),
  ])));
}

class _DroughtCard extends StatelessWidget {
  final WeatherFloodSnapshot snapshot;
  const _DroughtCard({required this.snapshot});
  @override
  Widget build(BuildContext context) {
    final stress = snapshot.droughtStatus == DroughtStatus.soilStress;
    final unavailable = snapshot.droughtStatus == DroughtStatus.unavailable;
    final color = stress
        ? Colors.red
        : unavailable
        ? Colors.orange
        : snapshot.droughtStatus == DroughtStatus.watch
        ? Colors.orange
        : AppTheme.primaryGreen;
    final title = stress
        ? 'ดินกำลังขาดน้ำ'
        : unavailable
        ? 'ยังประเมินภาวะแล้งไม่ได้'
        : snapshot.droughtStatus == DroughtStatus.watch
        ? 'เฝ้าระวังภาวะขาดน้ำ'
        : 'ยังไม่พบสัญญาณขาดน้ำ';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.water_drop_outlined, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(snapshot.droughtDetail),
                  if (snapshot.soilMoisture != null)
                    Text(
                      'ความชื้นดินล่าสุด ${snapshot.soilMoisture!.toStringAsFixed(1)}%',
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'เป็นตัวชี้วัดจากข้อมูลแปลง ไม่ใช่ประกาศภัยแล้งระดับจังหวัด',
                    style: TextStyle(fontSize: 12),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}
