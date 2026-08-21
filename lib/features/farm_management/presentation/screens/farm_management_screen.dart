import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/shared/widgets/reliable_satellite_layer.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'farm_map_screen.dart';
import 'package:chaona_app/shared/widgets/mascot_loading.dart';

class FarmManagementScreen extends ConsumerStatefulWidget {
  const FarmManagementScreen({super.key});

  @override
  ConsumerState<FarmManagementScreen> createState() =>
      _FarmManagementScreenState();
}

class _FarmManagementScreenState extends ConsumerState<FarmManagementScreen> {
  final _client = Supabase.instance.client;
  List<Farm> _farms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('farms')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final farms = (rows as List)
          .map((row) => _farmFromRow(Map<String, dynamic>.from(row)))
          .toList();
      if (mounted)
        setState(() {
          _farms = farms;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = _friendlyError(error.toString());
        });
    }
  }

  Farm _farmFromRow(Map<String, dynamic> row) {
    final rawBoundary = row['polygon_coordinates'];
    final boundary = rawBoundary is List
        ? rawBoundary.whereType<Map>().map((point) {
            final map = Map<String, dynamic>.from(point);
            return LatLng(
              (map['lat'] as num).toDouble(),
              (map['lng'] as num).toDouble(),
            );
          }).toList()
        : const <LatLng>[];
    return Farm(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      location: row['location'] as String?,
      areaRai: ((row['size'] as num?)?.toDouble() ?? 0) / 1600,
      cropType: row['crop_type'] as String? ?? 'rice',
      createdAt: DateTime.parse(row['created_at'] as String),
      plots: const [],
      boundary: boundary,
    );
  }

  Farm _mapPlaceholder() => Farm(
    id: 'new',
    userId: _client.auth.currentUser?.id ?? '',
    name: 'แปลงใหม่',
    areaRai: 0,
    cropType: 'rice',
    createdAt: DateTime.now(),
    plots: const [],
  );

  Future<void> _startCreate() async {
    final draft = await Navigator.push<FarmMapDraft>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FarmMapScreen(farm: _mapPlaceholder(), isCreating: true),
      ),
    );
    if (draft == null || !mounted) return;
    await _showFarmDetails(draft);
  }

  Future<void> _showFarmDetails(FarmMapDraft draft) async {
    final name = TextEditingController();
    final location = TextEditingController();
    var crop = 'rice';
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('รายละเอียดแปลง'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อแปลง',
                      hintText: 'เช่น แปลงนาบ้านเหนือ',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'กรุณาใส่ชื่อแปลง'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'จังหวัด/ตำแหน่ง',
                      hintText: 'เช่น อยุธยา',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'กรุณาใส่ตำแหน่ง'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: crop,
                    decoration: const InputDecoration(labelText: 'พืชหลัก'),
                    items: const [
                      DropdownMenuItem(value: 'rice', child: Text('ข้าว')),
                      DropdownMenuItem(value: 'corn', child: Text('ข้าวโพด')),
                      DropdownMenuItem(value: 'sugarcane', child: Text('อ้อย')),
                      DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                    ],
                    onChanged: (v) => setLocalState(() => crop = v ?? 'rice'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'พื้นที่ ${(draft.areaM2 / 1600).toStringAsFixed(2)} ไร่',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(
                    dialogContext,
                    await _saveFarm(
                      name.text.trim(),
                      location.text.trim(),
                      crop,
                      draft,
                    ),
                  );
                }
              },
              child: const Text('บันทึกแปลง'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    location.dispose();
    if (saved == true && mounted) await _loadFarms();
  }

  Future<void> _editFarm(Farm farm) async {
    final name = TextEditingController(text: farm.name);
    final location = TextEditingController(text: farm.location ?? '');
    var crop = farm.cropType;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('แก้ไขข้อมูลแปลง'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'ชื่อแปลง'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาใส่ชื่อแปลง'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: 'จังหวัด/ตำแหน่ง',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาใส่ตำแหน่ง'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: crop,
                  decoration: const InputDecoration(labelText: 'พืชหลัก'),
                  items: const [
                    DropdownMenuItem(value: 'rice', child: Text('ข้าว')),
                    DropdownMenuItem(value: 'corn', child: Text('ข้าวโพด')),
                    DropdownMenuItem(value: 'sugarcane', child: Text('อ้อย')),
                    DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => crop = value ?? 'rice'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  await _updateFarm(
                    farm,
                    name.text.trim(),
                    location.text.trim(),
                    crop,
                  ),
                );
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    location.dispose();
    if (saved == true && mounted) await _loadFarms();
  }

  Future<bool> _updateFarm(
    Farm farm,
    String name,
    String location,
    String crop,
  ) async {
    try {
      await _client
          .from('farms')
          .update({'name': name, 'location': location, 'crop_type': crop})
          .eq('id', farm.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('แก้ไขข้อมูลแปลงแล้ว')));
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error.toString()))),
        );
      }
      return false;
    }
  }

  Future<void> _openMap(Farm farm) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => FarmMapScreen(farm: farm)),
    );
    if (result is! List<LatLng> || result.length < 3) return;
    try {
      final areaM2 = _polygonArea(result);
      await _client
          .from('farms')
          .update({
            'size': areaM2,
            'polygon_coordinates': result
                .map((point) => {'lat': point.latitude, 'lng': point.longitude})
                .toList(),
          })
          .eq('id', farm.id);
      if (mounted) await _loadFarms();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error.toString()))),
        );
      }
    }
  }

  double _polygonArea(List<LatLng> points) {
    var area = 0.0;
    for (var i = 0; i < points.length; i++) {
      final next = (i + 1) % points.length;
      area += points[i].longitude * points[next].latitude;
      area -= points[next].longitude * points[i].latitude;
    }
    final avgLat =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
        points.length;
    return area.abs() / 2 * 111320 * 111320 * math.cos(avgLat * math.pi / 180);
  }

  Future<void> _deleteFarm(Farm farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบแปลงนี้หรือไม่?'),
        content: Text(
          'ข้อมูลแปลง ${farm.name} และข้อมูลที่เกี่ยวข้องจะถูกลบถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบแปลง'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('farms').delete().eq('id', farm.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบแปลงแล้ว')));
        await _loadFarms();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error.toString()))),
        );
      }
    }
  }

  Future<void> _addPlot(Farm farm) async {
    final name = TextEditingController();
    final area = TextEditingController();
    var crop = farm.cropType;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('เพิ่มแปลงย่อย'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อแปลงย่อย'),
              ),
              TextFormField(
                controller: area,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'พื้นที่ (ไร่)'),
              ),
              DropdownButtonFormField<String>(
                value: crop,
                decoration: const InputDecoration(labelText: 'พืช'),
                items: const [
                  DropdownMenuItem(value: 'rice', child: Text('ข้าว')),
                  DropdownMenuItem(value: 'corn', child: Text('ข้าวโพด')),
                  DropdownMenuItem(value: 'sugarcane', child: Text('อ้อย')),
                  DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                ],
                onChanged: (value) =>
                    setLocalState(() => crop = value ?? farm.cropType),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final parsedArea = double.tryParse(area.text.trim());
                if (name.text.trim().isEmpty ||
                    parsedArea == null ||
                    parsedArea <= 0)
                  return;
                try {
                  await _client.from('plots').insert({
                    'farm_id': farm.id,
                    'name': name.text.trim(),
                    'area': parsedArea,
                    'crop_type': crop,
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(_friendlyError(error.toString()))),
                    );
                  }
                }
              },
              child: const Text('เพิ่มแปลง'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    area.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มแปลงย่อยแล้ว')));
    }
  }

  Future<bool> _saveFarm(
    String name,
    String location,
    String crop,
    FarmMapDraft draft,
  ) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
      await _client.from('farms').insert({
        'user_id': user.id,
        'name': name,
        'location': location,
        'size': draft.areaM2,
        'crop_type': crop,
        'polygon_coordinates': draft.points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกแปลงสำเร็จ')));
      return true;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error.toString()))),
        );
      return false;
    }
  }

  String _friendlyError(String error) {
    if (error.contains('crop_type')) {
      return 'ฐานข้อมูลยังไม่มีช่องชนิดพืช กรุณารัน SQL migration ที่แนบไว้';
    }
    if ((error.contains('relation') && error.contains('farms')) ||
        error.contains('PGRT205') ||
        error.contains('PGRST205')) {
      return 'ยังไม่มีตาราง farms ใน Supabase กรุณารันไฟล์ docs/supabase/farms_table_setup.sql ใน SQL Editor';
    }
    if (error.contains('42501') ||
        error.toLowerCase().contains('row-level security')) {
      return 'Supabase ปฏิเสธการอ่านข้อมูล farms กรุณาตรวจสอบ RLS policy';
    }
    return 'โหลดข้อมูลแปลงไม่สำเร็จ\nรายละเอียด: $error';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: _farms.isEmpty
        ? null
        : FloatingActionButton.extended(
            onPressed: () => context.push('/farm-survey', extra: _farms.first),
            icon: const Icon(Icons.science_outlined),
            label: const Text('เริ่มตรวจดิน'),
          ),
    appBar: AppBar(
      title: const Text('แปลงของฉัน'),
      actions: [
        IconButton(
          onPressed: _startCreate,
          tooltip: 'สร้างแปลง',
          icon: const Icon(Icons.add_location_alt_outlined),
        ),
      ],
    ),
    body: _loading
        ? const MascotLoading(message: 'กำลังโหลดแปลงของคุณ...')
        : _error != null
        ? _ErrorState(message: _error!, onRetry: _loadFarms)
        : _farms.isEmpty
        ? _EmptyState(onAdd: _startCreate)
        : RefreshIndicator(
            onRefresh: _loadFarms,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _farms
                  .map(
                    (farm) => _FarmCard(
                      farm: farm,
                      onEdit: () => _editFarm(farm),
                      onDelete: () => _deleteFarm(farm),
                      onOpenMap: () => _openMap(farm),
                      onAddPlot: () => _addPlot(farm),
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_outlined,
              size: 42,
              color: AppTheme.primaryGreenDark,
            ),
          ),
          Image.asset('assets/images/mascot/mascot_map.png', width: 88, height: 88),
          const SizedBox(height: 20),
          Text(
            'ยังไม่มีแปลง',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'วาดขอบเขตบนแผนที่ แล้วเพิ่มชื่อ พืช และตำแหน่งของแปลง',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('สร้างแปลงแรก'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppTheme.statusModerate,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    ),
  );
}

class _FarmCard extends StatelessWidget {
  final Farm farm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenMap;
  final VoidCallback onAddPlot;
  const _FarmCard({
    required this.farm,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenMap,
    required this.onAddPlot,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Icon(
                  Icons.grass,
                  color: AppTheme.primaryGreenDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farm.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      farm.location ?? 'ไม่ระบุตำแหน่ง',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('แก้ไขข้อมูล'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('ลบแปลง'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (farm.boundary.length >= 3) ...[
            const SizedBox(height: 14),
            _FarmMiniMap(farm: farm, onTap: onOpenMap),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Info(
                icon: Icons.crop_square,
                text: '${farm.areaRai.toStringAsFixed(2)} ไร่',
              ),
              const SizedBox(width: 8),
              _Info(
                icon: Icons.grass,
                text: farm.cropType == 'rice' ? 'ข้าว' : farm.cropType,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('เปิดแผนที่'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddPlot,
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('เพิ่มแปลงย่อย'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FarmMiniMap extends StatelessWidget {
  final Farm farm;
  final VoidCallback onTap;
  const _FarmMiniMap({required this.farm, required this.onTap});

  LatLng get center {
    final lat = farm.boundary.map((p) => p.latitude).reduce((a, b) => a + b) / farm.boundary.length;
    final lng = farm.boundary.map((p) => p.longitude).reduce((a, b) => a + b) / farm.boundary.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 154,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 15.5, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
            children: [
              reliableSatelliteLayer(),
              PolygonLayer(polygons: [Polygon(points: farm.boundary, color: const Color(0x6637B77A), borderColor: Colors.white, borderStrokeWidth: 3)]),
              MarkerLayer(markers: [Marker(point: center, width: 32, height: 32, child: Container(decoration: BoxDecoration(color: AppTheme.primaryGreenDark, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.eco, size: 18, color: Colors.white))) ]),
            ],
          ),
          Positioned(left: 10, top: 10, child: _MapChip(text: 'ภาพดาวเทียม', icon: Icons.satellite_alt_outlined)),
          Positioned(right: 10, bottom: 10, child: _MapChip(text: 'แตะเพื่อเปิดแผนที่', icon: Icons.open_in_full)),
        ]),
      ),
    ),
  );
}

class _MapChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _MapChip({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black.withOpacity(.68), borderRadius: BorderRadius.circular(18)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))])),
  );
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.primaryGreenLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryGreenDark),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.primaryGreenDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
