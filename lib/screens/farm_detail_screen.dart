import 'package:flutter/material.dart';
import '../models/farm.dart';
import '../models/crop.dart';
import '../services/supabase_service.dart';
import 'farm_map_screen_osm.dart';

class FarmDetailScreen extends StatefulWidget {
  final Farm farm;

  const FarmDetailScreen({Key? key, required this.farm}) : super(key: key);

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  List<Crop> _crops = [];
  bool _isLoading = true;
  late Farm _farm;

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    try {
      final crops = await SupabaseService().getCrops(_farm.id);
      setState(() {
        _crops = crops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading crops: $e')));
      }
    }
  }

  Future<void> _refreshFarm() async {
    try {
      final farm = await SupabaseService().getFarmById(_farm.id);
      setState(() {
        _farm = farm;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing farm: $e')));
      }
    }
  }

  void _openFarmMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmMapScreenOSM(farmId: _farm.id),
      ),
    );

    // Refresh farm data if map was updated
    if (result == true) {
      _refreshFarm();
    }
  }

  String _formatArea(double area) {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(2)} m²';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_farm.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _openFarmMap,
            tooltip: 'View Farm Map',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Open edit farm dialog
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshFarm();
          await _loadCrops();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Farm Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.agriculture, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Farm Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: const Text('Location'),
                      subtitle: Text(_farm.location),
                    ),
                    ListTile(
                      leading: const Icon(Icons.square_foot),
                      title: const Text('Size'),
                      subtitle: Text(_formatArea(_farm.size)),
                    ),
                    if (_farm.polygonCoordinates != null)
                      ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        title: const Text('Farm boundary mapped'),
                        subtitle: Text(
                          '${_farm.polygonCoordinates!.length} points',
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openFarmMap,
                        icon: const Icon(Icons.map),
                        label: Text(
                          _farm.polygonCoordinates == null
                              ? 'Map Farm Boundary'
                              : 'View Farm Map',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Crops Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.grass, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Crops',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            // TODO: Open add crop dialog
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_crops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.grass,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No crops yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // TODO: Open add crop dialog
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Crop'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _crops.length,
                        itemBuilder: (context, index) {
                          final crop = _crops[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(crop.status),
                              child: const Icon(Icons.eco, color: Colors.white),
                            ),
                            title: Text('${crop.name} (${crop.variety})'),
                            subtitle: Text(
                              'Planted ${crop.daysPlanted} days ago',
                            ),
                            trailing: Chip(
                              label: Text(
                                crop.status.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: _getStatusColor(crop.status),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              // TODO: Open crop detail screen
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionButton(
                          icon: Icons.water_drop,
                          label: 'Log Irrigation',
                          onPressed: () {
                            // TODO: Log irrigation
                          },
                        ),
                        ActionButton(
                          icon: Icons.science,
                          label: 'Log Fertilizer',
                          onPressed: () {
                            // TODO: Log fertilizer
                          },
                        ),
                        ActionButton(
                          icon: Icons.bug_report,
                          label: 'Log Pest Control',
                          onPressed: () {
                            // TODO: Log pest control
                          },
                        ),
                        ActionButton(
                          icon: Icons.agriculture,
                          label: 'Log Harvest',
                          onPressed: () {
                            // TODO: Log harvest
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFarmMap,
        icon: const Icon(Icons.map),
        label: const Text('View Map'),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'growing':
        return Colors.green;
      case 'harvested':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
