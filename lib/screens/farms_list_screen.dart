import 'package:flutter/material.dart';
import '../models/farm.dart';
import '../services/supabase_service.dart';
import 'farm_detail_screen.dart';
import 'farm_map_screen_osm.dart';

class FarmsListScreen extends StatefulWidget {
  const FarmsListScreen({Key? key}) : super(key: key);

  @override
  State<FarmsListScreen> createState() => _FarmsListScreenState();
}

class _FarmsListScreenState extends State<FarmsListScreen> {
  List<Farm> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);
    try {
      final farms = await SupabaseService().getFarms();
      setState(() {
        _farms = farms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading farms: $e')));
      }
    }
  }

  void _showAddFarmDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final sizeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Farm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Farm Name',
                  hintText: 'e.g., North Field',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Pampanga, Philippines',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sizeController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Size (hectares)',
                  hintText: 'e.g., 2.5',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can map the exact boundaries later',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  locationController.text.isEmpty ||
                  sizeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                final sizeInHa = double.parse(sizeController.text);
                final sizeInM2 = sizeInHa * 10000; // Convert to m²

                await SupabaseService().createFarm(
                  nameController.text,
                  locationController.text,
                  sizeInM2,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadFarms();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Farm added successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteFarm(Farm farm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farm'),
        content: Text('Are you sure you want to delete "${farm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService().deleteFarm(farm.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadFarms();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Farm deleted')));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        title: const Text('My Farms'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFarms),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _farms.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadFarms,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _farms.length,
                itemBuilder: (context, index) {
                  final farm = _farms[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FarmDetailScreen(farm: farm),
                          ),
                        ).then((_) => _loadFarms());
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    farm.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        farm.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      Text(
                                        farm.location,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteFarm(farm);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoChip(
                                    Icons.square_foot,
                                    _formatArea(farm.size),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInfoChip(
                                    farm.polygonCoordinates != null
                                        ? Icons.check_circle
                                        : Icons.location_off,
                                    farm.polygonCoordinates != null
                                        ? 'Mapped'
                                        : 'Not Mapped',
                                    color: farm.polygonCoordinates != null
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FarmDetailScreen(farm: farm),
                                        ),
                                      ).then((_) => _loadFarms());
                                    },
                                    icon: const Icon(Icons.info_outline),
                                    label: const Text('Details'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FarmMapScreenOSM(farmId: farm.id),
                                        ),
                                      ).then((_) => _loadFarms());
                                    },
                                    icon: const Icon(Icons.map),
                                    label: const Text('Map'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFarmDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Farm'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 120, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No Farms Yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first farm to get started',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddFarmDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Farm'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.green,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
