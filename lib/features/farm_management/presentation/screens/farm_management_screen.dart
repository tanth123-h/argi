import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'farm_map_screen.dart';

class FarmManagementScreen extends ConsumerWidget {
  const FarmManagementScreen({super.key});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final demoPreset = ref.watch(demoModeNotifierProvider);
    final isDemo = demoPreset != DemoPreset.none;

    // Demo: show the current preset's farm
    // Real: this would come from a Supabase-backed provider
    final farms = isDemo ? [DemoFixtures.farmFor(demoPreset)] : <Farm>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการฟาร์ม'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มฟาร์ม',
            onPressed: () => _showAddDialog(ctx),
          ),
        ],
      ),
      body: farms.isEmpty
          ? _EmptyState(onAdd: () => _showAddDialog(ctx))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: farms.length,
              itemBuilder: (_, i) => _FarmCard(farm: farms[i]),
            ),
    );
  }

  void _showAddDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final areaCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('เพิ่มฟาร์มใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อฟาร์ม',
                hintText: 'เช่น แปลงนาบ้านเหนือ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'ที่ตั้ง',
                hintText: 'เช่น อ.บางปะอิน จ.อยุธยา',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'พื้นที่โดยประมาณ (ไร่)',
                hintText: 'เช่น 5',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: save via Supabase provider
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                ctx,
              ).showSnackBar(const SnackBar(content: Text('เพิ่มฟาร์มสำเร็จ')));
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farm card
// ---------------------------------------------------------------------------
class _FarmCard extends StatelessWidget {
  final Farm farm;
  const _FarmCard({required this.farm});

  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreenLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.grass,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm.name,
                          style: Theme.of(ctx).textTheme.headlineSmall,
                        ),
                        if (farm.location != null)
                          Text(
                            farm.location!,
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Chips row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.crop_square,
                    label: '${farm.areaRai.toStringAsFixed(1)} ไร่',
                  ),
                  _Chip(
                    icon: Icons.grass,
                    label: farm.cropType == 'rice' ? 'ข้าว' : farm.cropType,
                  ),
                  _Chip(
                    icon: Icons.schema_outlined,
                    label: '${farm.plots.length} แปลงย่อย',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Open map button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => FarmMapScreen(farm: farm),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('เปิดแผนที่ฟาร์ม'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryGreenDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreenDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 80,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 20),
            Text(
              'ยังไม่มีฟาร์ม',
              style: Theme.of(ctx).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'เพิ่มฟาร์มและวาดขอบเขตบนแผนที่\nเพื่อคำนวณพื้นที่และแผนการปลูก',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('+ เพิ่มฟาร์มแรก'),
            ),
          ],
        ),
      ),
    );
  }
}
