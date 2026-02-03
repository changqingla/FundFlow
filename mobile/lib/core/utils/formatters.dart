import 'package:intl/intl.dart';

/// Utility class for formatting values
class Formatters {
  Formatters._();

  /// Format a number as currency (CNY)
  static String formatCurrency(double value, {int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '¥',
      decimalDigits: decimalDigits,
    );
    return formatter.format(value);
  }

  /// Format a number as percentage
  static String formatPercentage(double value, {int decimalDigits = 2}) {
    final formatter = NumberFormat.percentPattern('zh_CN');
    formatter.minimumFractionDigits = decimalDigits;
    formatter.maximumFractionDigits = decimalDigits;
    return formatter.format(value / 100);
  }

  /// Format a number with sign (+ or -)
  static String formatWithSign(double value, {int decimalDigits = 2}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimalDigits)}';
  }

  /// Format a percentage with sign
  static String formatPercentageWithSign(double value, {int decimalDigits = 2}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimalDigits)}%';
  }

  /// Format a large number (e.g., 1.5亿, 3000万)
  static String formatLargeNumber(double value) {
    if (value.abs() >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(2)}亿';
    } else if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(2)}万';
    } else {
      return value.toStringAsFixed(2);
    }
  }

  /// Format a date
  static String formatDate(DateTime date, {String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern, 'zh_CN').format(date);
  }

  /// Format a time
  static String formatTime(DateTime time, {String pattern = 'HH:mm:ss'}) {
    return DateFormat(pattern, 'zh_CN').format(time);
  }

  /// Format a datetime
  static String formatDateTime(DateTime dateTime, {String pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    return DateFormat(pattern, 'zh_CN').format(dateTime);
  }

  /// Format a relative time (e.g., "5分钟前", "2小时前")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return formatDate(dateTime);
    }
  }
}
