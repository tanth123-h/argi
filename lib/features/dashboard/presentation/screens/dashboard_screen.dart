import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:chaona_app/features/weather_flood/data/weather_flood_service.dart';
import 'package:chaona_app/features/weather_flood/domain/entities/weather_flood_snapshot.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _client = Supabase.instance.client;
  final _weather = WeatherFloodService();
  List<Farm> _farms = const [];
  Farm? _farm;
  Map<String, dynamic>? _reading;
  WeatherFloodSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      _farms = (rows as List)
          .map((row) => _farmFromRow(Map<String, dynamic>.from(row)))
          .toList();
      _farm = _farms.isEmpty ? null : _farms.first;
      await _loadFarmData();
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  Future<void> _loadFarmData() async {
    final farm = _farm;
    if (farm == null) {
      if (mounted)
        setState(() {
          _reading = null;
          _snapshot = null;
          _loading = false;
        });
      return;
    }
    Map<String, dynamic>? reading;
    try {
      final readings = await SoilReadingRepository(
        _client,
      ).latestForFarm(farm.id);
      reading = readings.isEmpty ? null : readings.first;
    } catch (_) {}
    WeatherFloodSnapshot? snapshot;
    if (farm.boundary.length >= 3) {
      try {
        snapshot = await _weather.fetch(
          _center(farm),
          soilMoisture: (reading?['moisture'] as num?)?.toDouble(),
        );
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        _reading = reading;
        _snapshot = snapshot;
        _loading = false;
      });
  }

  Future<void> _selectFarm(Farm? farm) async {
    if (farm == null || farm == _farm) return;
    setState(() {
      _farm = farm;
      _loading = true;
    });
    try {
      await _loadFarmData();
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  Farm _farmFromRow(Map<String, dynamic> row) {
    final boundary = row['polygon_coordinates'] is List
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
      location: row['location'] as String?,
      areaRai: ((row['size'] as num?)?.toDouble() ?? 0) / 1600,
      cropType: row['crop_type'] as String? ?? 'rice',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      boundary: boundary,
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final profileName = (user?.userMetadata?['full_name'] as String?)?.trim();
    final name = profileName == null || profileName.isEmpty
        ? 'เกษตรกร'
        : profileName;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F1),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DashboardHeader(
              name: name,
              farms: _farms,
              farm: _farm,
              snapshot: _snapshot,
              loading: _loading,
              onFarmChanged: _selectFarm,
              onNotifications: () => context.push('/farm-tools'),
              onAi: () => context.push('/farm-analysis'),
              onLogout: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: _farm == null
                  ? _CreateFarm(onCreate: () => context.push('/farms'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) _Notice(text: _error!),
                        _FarmSummary(
                          farm: _farm!,
                          reading: _reading,
                          snapshot: _snapshot,
                          onOpen: () => context.push('/farm-tools'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'จัดการแปลงวันนี้',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.fieldInk,
                              ),
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .92,
                          children: [
                            _ActionTile(
                              icon: Icons.science_outlined,
                              label: 'ตรวจดิน',
                              color: const Color(0xFF2F7D58),
                              onTap: () => context.push('/soil'),
                            ),
                            _ActionTile(
                              icon: Icons.cloud_outlined,
                              label: 'อากาศ',
                              color: const Color(0xFF397A96),
                              onTap: () => context.push('/weather-flood'),
                            ),
                            _ActionTile(
                              icon: Icons.insights_outlined,
                              label: 'กราฟและแผน',
                              color: const Color(0xFFE29B35),
                              onTap: () => context.push('/farm-tools'),
                            ),
                            _ActionTile(
                              icon: Icons.auto_awesome_outlined,
                              label: 'AI วิเคราะห์',
                              color: const Color(0xFF7A5DA8),
                              onTap: () => context.push('/farm-analysis'),
                            ),
                            _ActionTile(
                              icon: Icons.storefront_outlined,
                              label: 'ราคาผลผลิต',
                              color: const Color(0xFFB65E3C),
                              onTap: () => context.push('/market'),
                            ),
                            _ActionTile(
                              icon: Icons.map_outlined,
                              label: 'แผนที่แปลง',
                              color: const Color(0xFF47705D),
                              onTap: () => context.push('/farms'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _TrustStrip(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  final List<Farm> farms;
  final Farm? farm;
  final WeatherFloodSnapshot? snapshot;
  final bool loading;
  final ValueChanged<Farm?> onFarmChanged;
  final VoidCallback onNotifications;
  final VoidCallback onAi;
  final VoidCallback onLogout;
  const _DashboardHeader({
    required this.name,
    required this.farms,
    required this.farm,
    required this.snapshot,
    required this.loading,
    required this.onFarmChanged,
    required this.onNotifications,
    required this.onAi,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF28623F),
    padding: EdgeInsets.fromLTRB(
      18,
      MediaQuery.paddingOf(context).top + 14,
      18,
      22,
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          top: 70,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFA9DB77).withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: const Color(0xFFE8F4D8),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF234C35),
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สวัสดี, $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        farm?.location ?? 'เลือกแปลงเพื่อเริ่มดูข้อมูล',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onAi,
                  tooltip: 'AI วิเคราะห์',
                  icon: const Icon(Icons.smart_toy_outlined),
                ),
                PopupMenuButton<String>(
                  iconColor: Colors.white,
                  onSelected: (value) {
                    if (value == 'alerts') onNotifications();
                    if (value == 'logout') onLogout();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'alerts', child: Text('การแจ้งเตือน')),
                    PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
                  ],
                ),
              ],
            ),
            if (farms.isNotEmpty) ...[
              const SizedBox(height: 18),
              DropdownButtonFormField<Farm>(
                value: farm,
                dropdownColor: const Color(0xFF234C35),
                iconEnabledColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'แปลงที่กำลังดู',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: .24),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFA9DB77)),
                  ),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                items: farms
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: onFarmChanged,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFA9DB77),
                borderRadius: BorderRadius.circular(8),
              ),
              child: loading
                  ? const LinearProgressIndicator()
                  : Row(
                      children: [
                        Icon(
                          snapshot == null
                              ? Icons.cloud_off_outlined
                              : Icons.wb_cloudy_outlined,
                          color: const Color(0xFF173F2C),
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot == null
                                    ? 'ยังไม่มีข้อมูลอากาศ'
                                    : '${snapshot!.temperatureC.toStringAsFixed(1)}°C  ${snapshot!.weatherLabel}',
                                style: const TextStyle(
                                  color: Color(0xFF173F2C),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                snapshot == null
                                    ? 'วาดขอบเขตแปลงเพื่อโหลดข้อมูล'
                                    : 'โอกาสฝนสูงสุด 24 ชม. ${snapshot!.rainProbability24h}%',
                                style: const TextStyle(
                                  color: Color(0xFF31593F),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF173F2C),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FarmSummary extends StatelessWidget {
  final Farm farm;
  final Map<String, dynamic>? reading;
  final WeatherFloodSnapshot? snapshot;
  final VoidCallback onOpen;
  const _FarmSummary({
    required this.farm,
    required this.reading,
    required this.snapshot,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final moisture = (reading?['moisture'] as num?)?.toDouble();
    final stale =
        reading == null ||
        DateTime.now()
                .difference(
                  DateTime.tryParse(
                        reading?['recorded_at']?.toString() ?? '',
                      ) ??
                      DateTime(2000),
                )
                .inMinutes >
            30;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE6D7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4D8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.landscape_outlined,
                    color: Color(0xFF28623F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.fieldInk,
                        ),
                      ),
                      Text(
                        '${_cropName(farm.cropType)} • ${farm.areaRai.toStringAsFixed(2)} ไร่',
                        style: const TextStyle(color: AppTheme.fieldMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  stale ? Icons.sensors_off_outlined : Icons.sensors,
                  color: stale ? Colors.orange : const Color(0xFF2F7D58),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'ความชื้นดิน',
                    value: moisture == null
                        ? '--'
                        : '${moisture.toStringAsFixed(0)}%',
                    color: const Color(0xFF397A96),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Metric(
                    label: 'pH',
                    value: reading?['ph']?.toString() ?? '--',
                    color: const Color(0xFF7A5DA8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Metric(
                    label: 'สถานะน้ำ',
                    value: snapshot?.droughtStatus == DroughtStatus.soilStress
                        ? 'ขาดน้ำ'
                        : 'ติดตาม',
                    color: snapshot?.droughtStatus == DroughtStatus.soilStress
                        ? Colors.red
                        : const Color(0xFFE29B35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _cropName(String value) => switch (value) {
    'rice' => 'ข้าว',
    'cassava' => 'มันสำปะหลัง',
    'corn' => 'ข้าวโพด',
    'sugarcane' => 'อ้อย',
    _ => value,
  };
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppTheme.fieldMuted),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE6D7)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.fieldInk,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreateFarm extends StatelessWidget {
  final VoidCallback onCreate;
  const _CreateFarm({required this.onCreate});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE6D7)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.add_location_alt_outlined,
          size: 48,
          color: Color(0xFF28623F),
        ),
        const SizedBox(height: 10),
        const Text(
          'สร้างแปลงแรกเพื่อเริ่มใช้งาน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.map_outlined),
          label: const Text('วาดขอบเขตแปลง'),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    color: const Color(0xFFFFF1D6),
    child: Text(text),
  );
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4EC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, color: Color(0xFF28623F)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'คำแนะนำใช้ข้อมูลแปลงจริง กฎที่ตรวจสอบได้ และแสดงแหล่งอ้างอิงทุกครั้ง',
            style: TextStyle(color: AppTheme.fieldInk, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
