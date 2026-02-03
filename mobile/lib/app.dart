import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';

/// Main application widget
///
/// Configures the app with:
/// - GoRouter for navigation with authentication guard
/// - Theme support (light/dark mode)
/// - Riverpod state management
///
/// Requirements: 17.2, 17.3
class FundAnalyzerApp extends ConsumerWidget {
  const FundAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '基金投资分析',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Router configuration
      routerConfig: router,
    );
  }
}
