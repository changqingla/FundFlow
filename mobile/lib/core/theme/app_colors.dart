import 'package:flutter/material.dart';

/// Application color definitions
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF1565C0);

  // Secondary colors
  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF00897B);

  // Stock market colors (Chinese market convention)
  // Red for up (涨), Green for down (跌)
  static const Color stockUp = Color(0xFFE53935); // Red - 上涨
  static const Color stockDown = Color(0xFF43A047); // Green - 下跌
  static const Color stockFlat = Color(0xFF9E9E9E); // Gray - 持平

  // Sentiment colors
  static const Color bullish = Color(0xFFE53935); // 利好 - Red
  static const Color bearish = Color(0xFF43A047); // 利空 - Green
  static const Color neutral = Color(0xFF9E9E9E); // 中性 - Gray

  // Background colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  // Error and warning colors
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);

  // Divider colors
  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF424242);
}
