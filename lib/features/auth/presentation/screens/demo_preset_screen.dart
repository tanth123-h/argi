import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/app/theme.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';

class DemoPresetScreen extends ConsumerWidget {
  const DemoPresetScreen({super.key});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกชุดข้อมูลสาธิต'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ctx.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ทดลองใช้งานโหมดสาธิต',
                style: Theme.of(ctx).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'เลือกสถานการณ์ที่ต้องการทดสอบ ข้อมูลจะไม่ถูกบันทึก',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Preset cards
              ...[
                DemoPreset.droughtLowN,
                DemoPreset.optimal,
                DemoPreset.highHumidityDisease,
              ].map((preset) => _PresetCard(
                    preset: preset,
                    onTap: () {
                      ref
                          .read(demoModeNotifierProvider.notifier)
                          .enterDemo(preset);
                      ctx.go('/home');
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final DemoPreset preset;
  final VoidCallback onTap;

  const _PresetCard({required this.preset, required this.onTap});

  IconData get _icon => switch (preset) {
        DemoPreset.droughtLowN => Icons.wb_sunny_outlined,
        DemoPreset.optimal => Icons.check_circle_outline,
        DemoPreset.highHumidityDisease => Icons.water_drop_outlined,
        DemoPreset.none => Icons.help_outline,
      };

  Color get _color => switch (preset) {
        DemoPreset.droughtLowN => AppTheme.statusPoor,
        DemoPreset.optimal => AppTheme.statusGood,
        DemoPreset.highHumidityDisease => AppTheme.statusModerate,
        DemoPreset.none => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DemoFixtures.presetNameThai(preset),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DemoFixtures.presetDescriptionThai(preset),
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
