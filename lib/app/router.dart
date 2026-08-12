import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chaona_app/features/auth/presentation/providers/demo_mode_provider.dart';
import 'package:chaona_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chaona_app/features/auth/presentation/screens/login_screen.dart';
import 'package:chaona_app/features/auth/presentation/screens/register_screen.dart';
import 'package:chaona_app/features/auth/presentation/screens/demo_preset_screen.dart';
import 'package:chaona_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:chaona_app/features/ai_chat/presentation/screens/chat_screen.dart';
import 'package:chaona_app/features/farm_management/presentation/screens/farm_management_screen.dart';
import 'package:chaona_app/features/market/presentation/screens/market_screen.dart';
import 'package:chaona_app/features/soil_monitoring/presentation/screens/soil_monitoring_screen.dart';
import 'package:chaona_app/features/fertilizer_recommendation/presentation/screens/fertilizer_screen.dart';
import 'package:chaona_app/shared/widgets/main_scaffold.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(RouterRef ref) {
  final demoMode = ref.watch(demoModeNotifierProvider);
  final isAuth = ref.watch(isAuthenticatedProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isDemo = demoMode != DemoPreset.none;
      final loc = state.matchedLocation;
      const authRoutes = ['/login', '/register', '/demo-preset'];
      final onAuthRoute = authRoutes.contains(loc);
      if (!isAuth && !isDemo && !onAuthRoute) return '/login';
      if ((isAuth || isDemo) && onAuthRoute && loc != '/demo-preset') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, s) => const RegisterScreen()),
      GoRoute(path: '/demo-preset', builder: (ctx, s) => const DemoPresetScreen()),
      GoRoute(path: '/market', builder: (ctx, s) => const MarketScreen()),
      GoRoute(path: '/fertilizer', builder: (ctx, s) => const FertilizerScreen()),
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (ctx, s) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/farms', builder: (ctx, s) => const FarmManagementScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/soil', builder: (ctx, s) => const SoilMonitoringScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/ai', builder: (ctx, s) => const ChatScreen())]),
        ],
      ),
    ],
  );
}
