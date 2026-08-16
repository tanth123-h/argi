import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';

// ---------------------------------------------------------------------------
// Provider: holds the list of drawn polygon points
// ---------------------------------------------------------------------------
final _polygonPointsProvider = StateProvider<List<LatLng>>((ref) => const []);

final _isDrawingProvider = StateProvider<bool>((ref) => false);

final _areaM2Provider = StateProvider<double?>((ref) => null);

final _plantSpacingProvider = StateProvider<double>((ref) => 30.0);
final _rowSpacingProvider = StateProvider<double>((ref) => 50.0);

class FarmMapDraft {
  final List<LatLng> points;
  final double areaM2;

  const FarmMapDraft({required this.points, required this.areaM2});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class FarmMapScreen extends ConsumerStatefulWidget {
  final Farm farm;
  final bool isCreating;

  const FarmMapScreen({super.key, required this.farm, this.isCreating = false});

  @override
  ConsumerState<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends ConsumerState<FarmMapScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(15.87, 100.99);

  @override
  void initState() {
    super.initState();
    // Reset state when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final boundary = widget.farm.boundary;
      ref.read(_polygonPointsProvider.notifier).state = boundary;
      ref.read(_isDrawingProvider.notifier).state = widget.isCreating;
      ref.read(_areaM2Provider.notifier).state = boundary.length >= 3
          ? _calcArea(boundary)
          : null;
      if (boundary.isNotEmpty) {
        setState(() => _center = boundary.first);
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _mapController.move(boundary.first, 17);
        });
      } else {
        _getCurrentLocation();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _mapController.move(loc, 18);
    } catch (_) {}
  }

  void _onTap(TapPosition _, LatLng point) {
    if (!ref.read(_isDrawingProvider)) return;

    final newPoint = LatLng(point.latitude, point.longitude);
    final List<LatLng> pts = [...ref.read(_polygonPointsProvider), newPoint];
    ref.read(_polygonPointsProvider.notifier).state = pts;

    if (pts.length >= 3) {
      ref.read(_areaM2Provider.notifier).state = _calcArea(pts);
    }
  }

  double _calcArea(List<LatLng> pts) {
    double area = 0;
    final n = pts.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += pts[i].longitude * pts[j].latitude;
      area -= pts[j].longitude * pts[i].latitude;
    }
    area = area.abs() / 2.0;

    final avgLat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / n;
    final latM = 111320.0;
    final lngM = 111320.0 * math.cos(avgLat * math.pi / 180);
    return area * latM * lngM;
  }

  void _undo() {
    final pts = [...ref.read(_polygonPointsProvider)];
    if (pts.isEmpty) return;
    pts.removeLast();
    ref.read(_polygonPointsProvider.notifier).state = pts;
    ref.read(_areaM2Provider.notifier).state = pts.length >= 3
        ? _calcArea(pts)
        : null;
  }

  void _clear() {
    ref.read(_polygonPointsProvider.notifier).state = [];
    ref.read(_areaM2Provider.notifier).state = null;
  }

  String _fmtArea(double m2) {
    final rai = m2 / 1600; // 1 rai = 1,600 m²
    final ha = m2 / 10000;
    return '${rai.toStringAsFixed(2)} ไร่  •  ${ha.toStringAsFixed(2)} ha  •  ${m2.toStringAsFixed(0)} m²';
  }

  int _estimatePlants(double m2, double plantCm, double rowCm) {
    final areaPerPlant = (plantCm / 100) * (rowCm / 100);
    return (m2 / areaPerPlant).floor();
  }

  @override
  Widget build(BuildContext context) {
    final pts = ref.watch(_polygonPointsProvider);
    final drawing = ref.watch(_isDrawingProvider);
    final area = ref.watch(_areaM2Provider);
    final pSpacing = ref.watch(_plantSpacingProvider);
    final rSpacing = ref.watch(_rowSpacingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreating ? 'วาดขอบเขตแปลง' : widget.farm.name),
        actions: [
          if (area != null)
            IconButton(
              icon: const Icon(Icons.eco_outlined),
              tooltip: 'แผนการปลูก',
              onPressed: () =>
                  _showPlantingSheet(context, area, pSpacing, rSpacing),
            ),
          IconButton(
            icon: Icon(drawing ? Icons.edit_off : Icons.edit_outlined),
            tooltip: drawing ? 'หยุดวาด' : 'วาดขอบเขต',
            onPressed: () =>
                ref.read(_isDrawingProvider.notifier).state = !drawing,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.chaona.app',
              ),
              PolygonLayer(
                polygons: [
                  if (pts.length >= 3)
                    Polygon(
                      points: pts,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.28),
                      borderColor: AppTheme.primaryGreen,
                      borderStrokeWidth: 3,
                      isFilled: true,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final point in pts)
                    Marker(
                      point: point,
                      width: 24,
                      height: 24,
                      child: const Icon(
                        Icons.location_on,
                        color: AppTheme.secondaryBrown,
                        size: 24,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'Esri, Maxar, Earthstar Geographics, and the GIS User Community',
                    prependCopyright: false,
                  ),
                ],
              ),
            ],
          ),

          // ── DRAWING BADGE ─────────────────────────────────────────────
          if (drawing)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBrown,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'แตะแผนที่เพื่อเพิ่มจุด  (${pts.length} จุด)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── AREA CARD ─────────────────────────────────────────────────
          if (area != null)
            Positioned(
              bottom: pts.isNotEmpty ? 88 : 16,
              left: 16,
              right: 16,
              child: _AreaCard(
                areaText: _fmtArea(area),
                plants: _estimatePlants(area, pSpacing, rSpacing),
              ),
            ),
        ],
      ),

      // ── BOTTOM TOOLBAR ───────────────────────────────────────────────
      bottomNavigationBar: pts.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _ToolButton(
                      icon: Icons.undo,
                      label: 'ยกเลิก',
                      onTap: _undo,
                    ),
                    const SizedBox(width: 8),
                    _ToolButton(
                      icon: Icons.delete_outline,
                      label: 'ล้าง',
                      onTap: _clear,
                      danger: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pts.length >= 3
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'บันทึกขอบเขตฟาร์ม  ${_fmtArea(area ?? 0)}',
                                    ),
                                  ),
                                );
                                if (widget.isCreating) {
                                  Navigator.pop(context, FarmMapDraft(points: pts, areaM2: area ?? 0));
                                } else {
                                  Navigator.pop(context, pts);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(widget.isCreating ? 'ถัดไป' : 'บันทึก'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'locate-farm',
        tooltip: 'Locate me',
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showPlantingSheet(
    BuildContext context,
    double area,
    double pSpacing,
    double rSpacing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlantingSheet(area: area),
    );
  }
}

// ---------------------------------------------------------------------------
// Area info card
// ---------------------------------------------------------------------------
class _AreaCard extends StatelessWidget {
  final String areaText;
  final int plants;

  const _AreaCard({required this.areaText, required this.plants});

  @override
  Widget build(BuildContext ctx) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.crop_free, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    areaText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreenDark,
                    ),
                  ),
                  Text(
                    'ประมาณ $plants ต้น',
                    style: const TextStyle(
                      fontSize: 14,
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

// ---------------------------------------------------------------------------
// Toolbar button
// ---------------------------------------------------------------------------
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext ctx) {
    final color = danger ? AppTheme.statusPoor : AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Planting strategy bottom sheet
// ---------------------------------------------------------------------------
class _PlantingSheet extends ConsumerWidget {
  final double area;
  const _PlantingSheet({required this.area});

  int _plants(double p, double r) => ((area) / ((p / 100) * (r / 100))).floor();

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final pSpacing = ref.watch(_plantSpacingProvider);
    final rSpacing = ref.watch(_rowSpacingProvider);
    final plants = _plants(pSpacing, rSpacing);
    final areaRai = area / 1600;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('แผนการปลูก', style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'พื้นที่ ${areaRai.toStringAsFixed(2)} ไร่  •  ${(area).toStringAsFixed(0)} m²',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Plant spacing slider
          _SliderRow(
            label: 'ระยะต้น',
            value: pSpacing,
            unit: 'ซม.',
            min: 10,
            max: 100,
            divisions: 18,
            onChanged: (v) =>
                ref.read(_plantSpacingProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),

          // Row spacing slider
          _SliderRow(
            label: 'ระยะแถว',
            value: rSpacing,
            unit: 'ซม.',
            min: 20,
            max: 150,
            divisions: 26,
            onChanged: (v) => ref.read(_rowSpacingProvider.notifier).state = v,
          ),
          const SizedBox(height: 24),

          // Result card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.grass,
                  color: AppTheme.primaryGreenDark,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'จำนวนต้นที่ปลูกได้',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '$plants ต้น',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreenDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '${value.toInt()} $unit',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreenDark,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
