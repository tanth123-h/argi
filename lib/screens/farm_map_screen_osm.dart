import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../models/farm.dart';

/// FREE OpenStreetMap Alternative to Google Maps
/// No API key required! Completely free!
class FarmMapScreenOSM extends StatefulWidget {
  final String farmId;

  const FarmMapScreenOSM({Key? key, required this.farmId}) : super(key: key);

  @override
  State<FarmMapScreenOSM> createState() => _FarmMapScreenOSMState();
}

class _FarmMapScreenOSMState extends State<FarmMapScreenOSM> {
  final MapController _mapController = MapController();
  final List<LatLng> _polygonPoints = [];
  bool _isDrawing = false;
  bool _isLoading = true;
  Farm? _farm;
  double? _calculatedArea;
  LatLng _center = LatLng(14.5995, 120.9842); // Philippines default

  // Planting strategy parameters
  double _plantSpacing = 30.0; // cm
  double _rowSpacing = 50.0; // cm
  int _estimatedPlants = 0;

  @override
  void initState() {
    super.initState();
    _loadFarm();
  }

  Future<void> _loadFarm() async {
    try {
      final farm = await SupabaseService().getFarmById(widget.farmId);
      setState(() {
        _farm = farm;
        _isLoading = false;
      });

      if (farm.polygonCoordinates != null &&
          farm.polygonCoordinates!.isNotEmpty) {
        _loadExistingPolygon(farm.polygonCoordinates!);
      } else {
        _getCurrentLocation();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading farm: $e')));
      }
    }
  }

  void _loadExistingPolygon(List<Map<String, double>> coordinates) {
    final points = coordinates.map((coord) {
      return LatLng(coord['lat']!, coord['lng']!);
    }).toList();

    setState(() {
      _polygonPoints.addAll(points);
      if (points.isNotEmpty) {
        _center = points.first;
      }
    });

    _calculateArea();
    _estimatePlantCount();

    // Move map to show polygon
    Future.delayed(const Duration(milliseconds: 500), () {
      if (points.isNotEmpty) {
        _mapController.move(_center, 16);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition();

      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_center, 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isDrawing) return;

    setState(() {
      _polygonPoints.add(point);

      if (_polygonPoints.length >= 3) {
        _calculateArea();
        _estimatePlantCount();
      }
    });
  }

  void _calculateArea() {
    if (_polygonPoints.length < 3) return;

    double area = 0.0;
    int j = _polygonPoints.length - 1;

    for (int i = 0; i < _polygonPoints.length; i++) {
      area +=
          (_polygonPoints[j].longitude + _polygonPoints[i].longitude) *
          (_polygonPoints[j].latitude - _polygonPoints[i].latitude);
      j = i;
    }

    area = area.abs() / 2.0;

    // Convert to square meters
    double avgLat =
        _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
        _polygonPoints.length;
    double latMeters = 111320;
    double lngMeters = 111320 * math.cos(avgLat * math.pi / 180);

    area = area * latMeters * lngMeters;

    setState(() {
      _calculatedArea = area;
    });
  }

  void _estimatePlantCount() {
    if (_calculatedArea == null) return;

    double plantSpacingM = _plantSpacing / 100;
    double rowSpacingM = _rowSpacing / 100;
    double areaPerPlant = plantSpacingM * rowSpacingM;
    int estimatedPlants = (_calculatedArea! / areaPerPlant).floor();

    setState(() {
      _estimatedPlants = estimatedPlants;
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _calculatedArea = null;
      _estimatedPlants = 0;
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        if (_polygonPoints.length >= 3) {
          _calculateArea();
          _estimatePlantCount();
        } else {
          _calculatedArea = null;
          _estimatedPlants = 0;
        }
      });
    }
  }

  Future<void> _saveFarmArea() async {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw at least 3 points')),
      );
      return;
    }

    try {
      final coordinates = _polygonPoints.map((point) {
        return {'lat': point.latitude, 'lng': point.longitude};
      }).toList();

      await SupabaseService().updateFarmPolygon(
        widget.farmId,
        coordinates,
        _calculatedArea ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Farm area saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving farm area: $e')));
      }
    }
  }

  void _showPlantingStrategyDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Planting Strategy'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Area: ${(_calculatedArea ?? 0).toStringAsFixed(2)} m²',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Plant Spacing (cm):'),
                Slider(
                  value: _plantSpacing,
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${_plantSpacing.toInt()} cm',
                  onChanged: (value) {
                    setDialogState(() => _plantSpacing = value);
                    setState(() {
                      _plantSpacing = value;
                      _estimatePlantCount();
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text('Row Spacing (cm):'),
                Slider(
                  value: _rowSpacing,
                  min: 20,
                  max: 150,
                  divisions: 26,
                  label: '${_rowSpacing.toInt()} cm',
                  onChanged: (value) {
                    setDialogState(() => _rowSpacing = value);
                    setState(() {
                      _rowSpacing = value;
                      _estimatePlantCount();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Plants:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_estimatedPlants plants',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Planting strategy: $_estimatedPlants plants',
                    ),
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Farm Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_farm?.name ?? 'Farm Map'),
        actions: [
          if (_polygonPoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.calculate),
              onPressed: _showPlantingStrategyDialog,
              tooltip: 'Planting Strategy',
            ),
          IconButton(
            icon: Icon(_isDrawing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() => _isDrawing = !_isDrawing);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isDrawing
                        ? 'Tap on map to draw farm boundary'
                        : 'Drawing mode disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: _isDrawing ? 'Finish Drawing' : 'Start Drawing',
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap - FREE! No API key needed!
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16.0,
              onTap: _onMapTap,
            ),
            children: [
              // OpenStreetMap tiles - FREE!
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.argi',
                maxZoom: 19,
              ),

              // Polygon layer
              if (_polygonPoints.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: Colors.green.withOpacity(0.3),
                      borderColor: Colors.green,
                      borderStrokeWidth: 3,
                      isFilled: true,
                    ),
                  ],
                ),

              // Markers layer
              MarkerLayer(
                markers: _polygonPoints
                    .asMap()
                    .entries
                    .map(
                      (entry) => Marker(
                        point: entry.value,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            // Marker dragging would need custom implementation
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),

          // Info overlay
          if (_calculatedArea != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Farm Area',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(_calculatedArea! / 10000).toStringAsFixed(2)} ha',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_calculatedArea!.toStringAsFixed(2)} m²'),
                          if (_estimatedPlants > 0)
                            Text(
                              '~$_estimatedPlants plants',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Drawing status
          if (_isDrawing)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Drawing: ${_polygonPoints.length} points',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Attribution (required for OpenStreetMap)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              color: Colors.white.withOpacity(0.7),
              padding: const EdgeInsets.all(4),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _polygonPoints.isNotEmpty
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _undoLastPoint,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    TextButton.icon(
                      onPressed: _clearPolygon,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    ElevatedButton.icon(
                      onPressed: _polygonPoints.length >= 3
                          ? _saveFarmArea
                          : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Area'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
