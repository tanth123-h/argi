import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const MainScaffold({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoModeProvider);
    return Scaffold(
      body: Column(
        children: [
          if (isDemo) const _DemoBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'My Farm'),
          NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors), label: 'Monitor'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Chaona AI'),
        ],
      ),
    );
  }
}

class _DemoBanner extends ConsumerWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
        color: const Color(0xFFFFF3CD),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.science_outlined, color: Color(0xFF8A5A00), size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Demo data: readings are simulated.')),
              TextButton(
                onPressed: () => context.push('/demo-preset'),
                child: const Text('Change'),
              ),
            ]),
          ),
        ),
      );
}
