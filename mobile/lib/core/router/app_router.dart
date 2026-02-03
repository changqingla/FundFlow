import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/auth/forgot_password_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/fund/add_fund_page.dart';
import '../../presentation/pages/fund/fund_detail_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/market/minute_chart_page.dart';
import '../../presentation/pages/market/precious_metals_page.dart';
import '../../presentation/pages/market/volume_trend_page.dart';
import '../../presentation/pages/sector/sector_funds_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/providers/auth_provider.dart';

/// Route names for navigation
///
/// Use these constants for type-safe navigation throughout the app.
/// Example: context.goNamed(AppRoutes.home)
///
/// Requirements: 17.2
class AppRoutes {
  // Auth routes
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';

  // Main routes
  static const String home = 'home';
  static const String settings = 'settings';

  // Fund routes
  static const String fundDetail = 'fund-detail';
  static const String addFund = 'add-fund';

  // Market routes
  static const String preciousMetals = 'precious-metals';
  static const String volumeTrend = 'volume-trend';
  static const String minuteChart = 'minute-chart';

  // Sector routes
  static const String sectorFunds = 'sector-funds';

  // Private constructor to prevent instantiation
  AppRoutes._();
}

/// Route paths for navigation
///
/// These are the actual URL paths used in the router.
class AppPaths {
  // Auth paths
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main paths
  static const String home = '/';
  static const String settings = '/settings';

  // Fund paths
  static const String fundDetail = '/fund/:code';
  static const String addFund = '/fund/add';

  // Market paths
  static const String preciousMetals = '/market/precious-metals';
  static const String volumeTrend = '/market/volume-trend';
  static const String minuteChart = '/market/minute-chart';

  // Sector paths
  static const String sectorFunds = '/sector/:id/funds';

  // Private constructor to prevent instantiation
  AppPaths._();
}

/// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider
///
/// Provides the GoRouter instance configured with:
/// - Authentication guard (redirects to login if not authenticated)
/// - Named routes for all pages
/// - Deep linking support
///
/// Requirements: 17.2, 25.2
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state for redirect logic
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.home,
    debugLogDiagnostics: true,

    // Redirect logic for authentication guard
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == AppPaths.login ||
          state.matchedLocation == AppPaths.register ||
          state.matchedLocation == AppPaths.forgotPassword;

      // If not authenticated and not on auth route, redirect to login
      if (!isAuthenticated && !isAuthRoute) {
        // Store the intended destination for redirect after login
        return '${AppPaths.login}?redirect=${Uri.encodeComponent(state.matchedLocation)}';
      }

      // If authenticated and on auth route, redirect to home
      if (isAuthenticated && isAuthRoute) {
        // Check if there's a redirect parameter
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null && redirect.isNotEmpty) {
          return Uri.decodeComponent(redirect);
        }
        return AppPaths.home;
      }

      // No redirect needed
      return null;
    },

    // Error page builder
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '页面不存在',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? '请检查链接是否正确',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppPaths.home),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),

    // Route definitions
    routes: [
      // ==================== Auth Routes ====================

      /// Login page
      GoRoute(
        path: AppPaths.login,
        name: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      /// Register page
      GoRoute(
        path: AppPaths.register,
        name: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),

      /// Forgot password page
      GoRoute(
        path: AppPaths.forgotPassword,
        name: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // ==================== Main Routes ====================

      /// Home page with bottom navigation tabs
      /// Tabs: 快讯, 市场, 基金, 板块, AI 聊天
      GoRoute(
        path: AppPaths.home,
        name: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),

      /// Settings page
      GoRoute(
        path: AppPaths.settings,
        name: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),

      // ==================== Fund Routes ====================

      /// Add fund page
      GoRoute(
        path: AppPaths.addFund,
        name: AppRoutes.addFund,
        builder: (context, state) => const AddFundPage(),
      ),

      /// Fund detail page
      GoRoute(
        path: AppPaths.fundDetail,
        name: AppRoutes.fundDetail,
        builder: (context, state) {
          final fundCode = state.pathParameters['code'] ?? '';
          return FundDetailPage(fundCode: fundCode);
        },
      ),

      // ==================== Market Routes ====================

      /// Precious metals page
      GoRoute(
        path: AppPaths.preciousMetals,
        name: AppRoutes.preciousMetals,
        builder: (context, state) => const PreciousMetalsPage(),
      ),

      /// Volume trend page
      GoRoute(
        path: AppPaths.volumeTrend,
        name: AppRoutes.volumeTrend,
        builder: (context, state) => const VolumeTrendPage(),
      ),

      /// Minute chart page
      GoRoute(
        path: AppPaths.minuteChart,
        name: AppRoutes.minuteChart,
        builder: (context, state) => const MinuteChartPage(),
      ),

      // ==================== Sector Routes ====================

      /// Sector funds page
      GoRoute(
        path: AppPaths.sectorFunds,
        name: AppRoutes.sectorFunds,
        builder: (context, state) {
          final sectorId = state.pathParameters['id'] ?? '';
          final sectorName =
              state.uri.queryParameters['name'] ?? '板块';
          return SectorFundsPage(
            sectorId: sectorId,
            sectorName: sectorName,
          );
        },
      ),
    ],
  );
});

/// Extension methods for easier navigation
///
/// Usage:
/// ```dart
/// context.goToHome();
/// context.goToFundDetail('000001');
/// context.goToSectorFunds('BK0001', '科技');
/// ```
extension AppRouterExtension on BuildContext {
  // Auth navigation
  void goToLogin() => go(AppPaths.login);
  void goToRegister() => go(AppPaths.register);
  void goToForgotPassword() => go(AppPaths.forgotPassword);

  // Main navigation
  void goToHome() => go(AppPaths.home);
  void goToSettings() => go(AppPaths.settings);

  // Fund navigation
  void goToAddFund() => go(AppPaths.addFund);
  void goToFundDetail(String fundCode) => go('/fund/$fundCode');

  // Market navigation
  void goToPreciousMetals() => go(AppPaths.preciousMetals);
  void goToVolumeTrend() => go(AppPaths.volumeTrend);
  void goToMinuteChart() => go(AppPaths.minuteChart);

  // Sector navigation
  void goToSectorFunds(String sectorId, String sectorName) =>
      go('/sector/$sectorId/funds?name=${Uri.encodeComponent(sectorName)}');

  // Push navigation (adds to stack instead of replacing)
  void pushToSettings() => push(AppPaths.settings);
  void pushToAddFund() => push(AppPaths.addFund);
  void pushToFundDetail(String fundCode) => push('/fund/$fundCode');
  void pushToPreciousMetals() => push(AppPaths.preciousMetals);
  void pushToVolumeTrend() => push(AppPaths.volumeTrend);
  void pushToMinuteChart() => push(AppPaths.minuteChart);
  void pushToSectorFunds(String sectorId, String sectorName) =>
      push('/sector/$sectorId/funds?name=${Uri.encodeComponent(sectorName)}');
}
