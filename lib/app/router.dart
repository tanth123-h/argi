import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/features/auth/presentation/screens/login_screen.dart';
import 'package:chaona_app/features/auth/presentation/screens/register_screen.dart';
import 'package:chaona_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:chaona_app/features/ai_chat/presentation/screens/chat_screen.dart';
import 'package:chaona_app/features/farm_management/presentation/screens/farm_management_screen.dart';
import 'package:chaona_app/features/market/presentation/screens/market_screen.dart';
import 'package:chaona_app/features/soil_monitoring/presentation/screens/soil_monitoring_screen.dart';
import 'package:chaona_app/features/soil_survey/presentation/screens/farm_soil_survey_screen.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/fertilizer_recommendation/presentation/screens/fertilizer_screen.dart';
import 'package:chaona_app/features/weather_flood/presentation/screens/weather_flood_screen.dart';
import 'package:chaona_app/features/ai_chat/presentation/screens/farm_analysis_screen.dart';
import 'package:chaona_app/features/farm_tools/presentation/screens/farm_tools_screen.dart';
import 'package:chaona_app/shared/widgets/main_scaffold.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(RouterRef ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      const authRoutes = ['/login', '/register'];
      final onAuthRoute = authRoutes.contains(loc);
      if (!isAuth && !onAuthRoute) return '/login';
      if (isAuth && onAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, s) => const RegisterScreen()),
      GoRoute(path: '/market', builder: (ctx, s) => const MarketScreen()),
      GoRoute(
        path: '/fertilizer',
        builder: (ctx, s) => const FertilizerScreen(),
      ),
      GoRoute(
        path: '/farm-survey',
        builder: (ctx, s) {
          final farm = s.extra;
          if (farm is Farm) return FarmSoilSurveyScreen(farm: farm);
          return const _MissingFarmSurveyRoute();
        },
      ),
      GoRoute(
        path: '/farm-analysis',
        builder: (ctx, s) => const FarmAnalysisScreen(),
      ),
      GoRoute(
        path: '/farm-tools',
        builder: (ctx, s) => const FarmToolsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (ctx, s) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farms',
                builder: (ctx, s) => const FarmManagementScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/soil',
                builder: (ctx, s) => const SoilMonitoringScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/weather-flood',
                builder: (ctx, s) => const WeatherFloodScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/ai', builder: (ctx, s) => const ChatScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

class _MissingFarmSurveyRoute extends StatelessWidget {
  const _MissingFarmSurveyRoute();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('เริ่มตรวจดิน')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'ยังไม่ได้เลือกฟาร์ม',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('กลับไปเลือกฟาร์ม แล้วกดเริ่มตรวจดินอีกครั้ง'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/farms'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('กลับไปฟาร์มของฉัน'),
                ),
              ],
            ),
          ),
        ),
      );
}
