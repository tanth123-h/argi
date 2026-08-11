import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/core/utils/soil_calculator.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_data.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final demoPreset = ref.watch(demoModeNotifierProvider);
    final isDemo = demoPreset != DemoPreset.none;

    // Use demo fixtures or null (real data wired in Phase 2)
    final farm = isDemo ? DemoFixtures.farmFor(demoPreset) : null;
    final soil = isDemo ? DemoFixtures.soilFor(demoPreset) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ชาวนา AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).signOut();
                if (ctx.mounted) {
                  ctx.go('/login');
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('โปรไฟล์'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 8),
                    Text('ตั้งค่า'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: farm == null
          ? _EmptyState(onAddFarm: () => ctx.push('/farms'))
          : _DashboardContent(farm: farm, soil: soil),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — no farm registered yet
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddFarm;
  const _EmptyState({required this.onAddFarm});

  @override
  Widget build(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.grass_outlined,
              size: 80,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'ยังไม่มีฟาร์มของคุณ',
              style: Theme.of(ctx).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'เริ่มต้นด้วยการเพิ่มแปลงนาของคุณ\nเพื่อติดตามสุขภาพดินและรับคำแนะนำ AI',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddFarm,
                icon: const Icon(Icons.add),
                label: const Text('+ เพิ่มฟาร์มของคุณ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main dashboard content
// ---------------------------------------------------------------------------
class _DashboardContent extends StatelessWidget {
  final dynamic farm; // Farm entity — typed fully in Phase 2
  final SoilData? soil;

  const _DashboardContent({required this.farm, this.soil});

  @override
  Widget build(BuildContext ctx) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _FarmStatusCard(farm: farm),
          if (soil != null) _SoilCard(soil: soil!),
          _WeatherCard(),
          _AiRecommendationCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farm Status Card
// ---------------------------------------------------------------------------
class _FarmStatusCard extends StatelessWidget {
  final dynamic farm;
  const _FarmStatusCard({required this.farm});

  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grass,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm?.name ?? 'ฟาร์ม',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${farm?.cropType == 'rice' ? 'ข้าว' : farm?.cropType} • ${farm?.areaRai} ไร่',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ปกติ',
                style: TextStyle(
                  color: AppTheme.primaryGreenDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Soil Status Card
// ---------------------------------------------------------------------------
class _SoilCard extends StatelessWidget {
  final SoilData soil;
  const _SoilCard({required this.soil});

  @override
  Widget build(BuildContext ctx) {
    final score = SoilCalculator.calculate(soil);

    return Card(
      child: InkWell(
        onTap: () => ctx.push('/soil'), // Navigate to soil monitoring
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text('สุขภาพดิน', style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  // Composite score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: score.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.composite.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: score.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          score.labelThai,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: score.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // NPK + moisture row
              Row(
                children: [
                  _MetricChip(
                    label: 'ความชื้น',
                    value: '${soil.moisture.toStringAsFixed(0)}%',
                    status: SoilCalculator.moistureStatus(soil.moisture),
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'N',
                    value: soil.nitrogen.toStringAsFixed(0),
                    status: SoilCalculator.npkStatus(soil.nitrogen),
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'P',
                    value: soil.phosphorus.toStringAsFixed(0),
                    status: SoilCalculator.npkStatus(soil.phosphorus),
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'K',
                    value: soil.potassium.toStringAsFixed(0),
                    status: SoilCalculator.npkStatus(soil.potassium),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final NutrientStatus status;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.status,
  });

  Color get _color => switch (status) {
    NutrientStatus.normal => AppTheme.statusGood,
    NutrientStatus.low => AppTheme.statusPoor,
    NutrientStatus.high => AppTheme.statusModerate,
  };

  @override
  Widget build(BuildContext ctx) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather Card (placeholder — wired in Phase 2)
// ---------------------------------------------------------------------------
class _WeatherCard extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.wb_cloudy_outlined,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สภาพอากาศ', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'กำลังโหลดข้อมูลสภาพอากาศ...',
                    style: Theme.of(ctx).textTheme.bodyMedium,
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
// AI Recommendation Card (placeholder — wired in Phase 2)
// ---------------------------------------------------------------------------
class _AiRecommendationCard extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.08),
              AppTheme.primaryGreenLight,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI แนะนำ',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryGreenDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'แตะเพื่อรับคำแนะนำจาก AI เกี่ยวกับการใส่ปุ๋ยและการดูแลแปลงนา',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ถาม AI เพิ่มเติม'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
