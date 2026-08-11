import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/app/theme.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const MainScaffold({super.key, required this.shell});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final isDemo = ref.watch(isDemoModeProvider);

    return Scaffold(
      body: Column(
        children: [
          // Demo mode banner — shown on every screen
          if (isDemo) const _DemoBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'ฟาร์ม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: 'ราคา',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors_outlined),
            activeIcon: Icon(Icons.sensors),
            label: 'เซ็นเซอร์',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined),
            activeIcon: Icon(Icons.science),
            label: 'ปุ๋ย',
          ),
        ],
      ),
    );
  }
}

class _DemoBanner extends ConsumerWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'โหมดสาธิต — ข้อมูลไม่ถูกบันทึก',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ctx.push('/demo-preset'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.secondaryBrown,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('เปลี่ยนชุดข้อมูล'),
            ),
          ],
        ),
      ),
    );
  }
}
