import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/network/api_client.dart';

/// Error types for categorizing different failure scenarios
enum ErrorType {
  /// Network-related errors (timeout, no connection, etc.)
  network,

  /// API errors returned from the server
  api,

  /// Validation errors (invalid input)
  validation,

  /// Authentication errors (unauthorized, token expired)
  authentication,

  /// Permission errors (forbidden)
  permission,

  /// Resource not found errors
  notFound,

  /// Rate limiting errors
  rateLimited,

  /// Unknown/unexpected errors
  unknown,
}

/// Severity level for errors
enum ErrorSeverity {
  /// Low severity - informational
  low,

  /// Medium severity - warning
  medium,

  /// High severity - error
  high,

  /// Critical severity - fatal error
  critical,
}

/// Unified error information class
class ErrorInfo {
  /// The type of error
  final ErrorType type;

  /// User-friendly error message (in Chinese)
  final String userMessage;

  /// Technical error message for debugging
  final String technicalMessage;

  /// Error severity level
  final ErrorSeverity severity;

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// API error code (if applicable)
  final int? apiCode;

  /// Original exception
  final dynamic originalError;

  /// Stack trace (if available)
  final StackTrace? stackTrace;

  /// Timestamp when the error occurred
  final DateTime timestamp;

  /// Whether the error is recoverable
  final bool isRecoverable;

  /// Suggested action for the user
  final String? suggestedAction;

  ErrorInfo({
    required this.type,
    required this.userMessage,
    required this.technicalMessage,
    this.severity = ErrorSeverity.medium,
    this.statusCode,
    this.apiCode,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
    this.isRecoverable = true,
    this.suggestedAction,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ErrorInfo(type: $type, userMessage: $userMessage, '
        'technicalMessage: $technicalMessage, statusCode: $statusCode, '
        'apiCode: $apiCode, severity: $severity)';
  }
}

/// Unified error handler for the application
///
/// Provides:
/// - Error classification (network, API, validation, etc.)
/// - User-friendly error messages in Chinese
/// - Error logging for debugging
/// - Snackbar/Toast display helpers
/// - Dialog display helpers
///
/// Usage:
/// ```dart
/// try {
///   await someApiCall();
/// } catch (e, stackTrace) {
///   final errorInfo = ErrorHandler.handleError(e, stackTrace);
///   ErrorHandler.showSnackBar(context, errorInfo);
/// }
/// ```
class ErrorHandler {
  ErrorHandler._();

  /// Callback for logging errors (can be customized)
  static void Function(ErrorInfo errorInfo)? onError;

  /// Callback for handling authentication errors (e.g., logout)
  static void Function()? onAuthenticationError;

  /// Handle any exception and convert it to ErrorInfo
  ///
  /// [error] - The exception to handle
  /// [stackTrace] - Optional stack trace
  /// [context] - Optional context for additional error information
  static ErrorInfo handleError(
    dynamic error, [
    StackTrace? stackTrace,
    String? context,
  ]) {
    ErrorInfo errorInfo;

    if (error is NetworkException) {
      errorInfo = _handleNetworkException(error, stackTrace);
    } else if (error is ApiException) {
      errorInfo = _handleApiException(error, stackTrace);
    } else if (error is DioException) {
      errorInfo = _handleDioException(error, stackTrace);
    } else if (error is SocketException) {
      errorInfo = _handleSocketException(error, stackTrace);
    } else if (error is FormatException) {
      errorInfo = _handleFormatException(error, stackTrace);
    } else if (error is TypeError) {
      errorInfo = _handleTypeError(error, stackTrace);
    } else {
      errorInfo = _handleUnknownError(error, stackTrace);
    }

    // Log the error
    _logError(errorInfo, context);

    // Trigger authentication error callback if needed
    if (errorInfo.type == ErrorType.authentication) {
      onAuthenticationError?.call();
    }

    // Trigger general error callback
    onError?.call(errorInfo);

    return errorInfo;
  }

  /// Handle NetworkException
  static ErrorInfo _handleNetworkException(
    NetworkException error,
    StackTrace? stackTrace,
  ) {
    ErrorType type;
    String userMessage;
    ErrorSeverity severity;
    bool isRecoverable;
    String? suggestedAction;

    switch (error.type) {
      case NetworkErrorType.timeout:
        type = ErrorType.network;
        userMessage = '请求超时，请检查网络连接后重试';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查网络连接或稍后重试';
        break;

      case NetworkErrorType.noConnection:
        type = ErrorType.network;
        userMessage = '网络连接失败，请检查网络设置';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查网络连接后重试';
        break;

      case NetworkErrorType.serverError:
        type = ErrorType.api;
        userMessage = '服务器繁忙，请稍后重试';
        severity = ErrorSeverity.high;
        isRecoverable = true;
        suggestedAction = '请稍后重试';
        break;

      case NetworkErrorType.unauthorized:
        type = ErrorType.authentication;
        userMessage = '登录已过期，请重新登录';
        severity = ErrorSeverity.high;
        isRecoverable = true;
        suggestedAction = '请重新登录';
        break;

      case NetworkErrorType.rateLimited:
        type = ErrorType.rateLimited;
        userMessage = '请求过于频繁，请稍后重试';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请等待一段时间后重试';
        break;

      case NetworkErrorType.badRequest:
        type = ErrorType.validation;
        userMessage = error.message.isNotEmpty ? error.message : '请求参数错误';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查输入内容';
        break;

      case NetworkErrorType.notFound:
        type = ErrorType.notFound;
        userMessage = '请求的资源不存在';
        severity = ErrorSeverity.medium;
        isRecoverable = false;
        suggestedAction = null;
        break;

      case NetworkErrorType.unknown:
      default:
        type = ErrorType.unknown;
        userMessage = '网络请求失败，请稍后重试';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请稍后重试';
        break;
    }

    return ErrorInfo(
      type: type,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: severity,
      statusCode: error.statusCode,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: isRecoverable,
      suggestedAction: suggestedAction,
    );
  }

  /// Handle ApiException
  static ErrorInfo _handleApiException(
    ApiException error,
    StackTrace? stackTrace,
  ) {
    // Map API error codes to user-friendly messages
    String userMessage;
    ErrorType type;
    ErrorSeverity severity;
    bool isRecoverable;
    String? suggestedAction;

    switch (error.code) {
      // Authentication errors (1xxx)
      case 1001:
        type = ErrorType.validation;
        userMessage = '邮箱格式不正确';
        severity = ErrorSeverity.low;
        isRecoverable = true;
        suggestedAction = '请输入正确的邮箱地址';
        break;

      case 1002:
        type = ErrorType.validation;
        userMessage = '密码格式不正确';
        severity = ErrorSeverity.low;
        isRecoverable = true;
        suggestedAction = '密码需要至少8位，包含字母和数字';
        break;

      case 1003:
        type = ErrorType.validation;
        userMessage = '该邮箱已被注册';
        severity = ErrorSeverity.low;
        isRecoverable = true;
        suggestedAction = '请使用其他邮箱或直接登录';
        break;

      case 1004:
        type = ErrorType.authentication;
        userMessage = '用户不存在';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查邮箱地址或注册新账号';
        break;

      case 1005:
        type = ErrorType.authentication;
        userMessage = '密码错误';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查密码或使用忘记密码功能';
        break;

      case 1006:
        type = ErrorType.authentication;
        userMessage = '账号已被锁定，请稍后重试';
        severity = ErrorSeverity.high;
        isRecoverable = true;
        suggestedAction = '请等待15分钟后重试';
        break;

      case 1007:
        type = ErrorType.validation;
        userMessage = '验证码错误或已过期';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请重新获取验证码';
        break;

      case 1008:
        type = ErrorType.authentication;
        userMessage = '登录已过期，请重新登录';
        severity = ErrorSeverity.high;
        isRecoverable = true;
        suggestedAction = '请重新登录';
        break;

      // Fund errors (2xxx)
      case 2001:
        type = ErrorType.validation;
        userMessage = '基金代码不存在';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请检查基金代码是否正确';
        break;

      case 2002:
        type = ErrorType.validation;
        userMessage = '该基金已在自选列表中';
        severity = ErrorSeverity.low;
        isRecoverable = false;
        suggestedAction = null;
        break;

      case 2003:
        type = ErrorType.notFound;
        userMessage = '基金不在自选列表中';
        severity = ErrorSeverity.low;
        isRecoverable = false;
        suggestedAction = null;
        break;

      // Data errors (3xxx)
      case 3001:
        type = ErrorType.api;
        userMessage = '数据获取失败，请稍后重试';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请稍后重试';
        break;

      case 3002:
        type = ErrorType.api;
        userMessage = '数据源暂时不可用';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请稍后重试';
        break;

      // Default handling
      default:
        type = ErrorType.api;
        userMessage = error.message.isNotEmpty ? error.message : '操作失败，请稍后重试';
        severity = ErrorSeverity.medium;
        isRecoverable = true;
        suggestedAction = '请稍后重试';
        break;
    }

    return ErrorInfo(
      type: type,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: severity,
      apiCode: error.code,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: isRecoverable,
      suggestedAction: suggestedAction,
    );
  }

  /// Handle DioException directly (fallback)
  static ErrorInfo _handleDioException(
    DioException error,
    StackTrace? stackTrace,
  ) {
    ErrorType type;
    String userMessage;
    ErrorSeverity severity;
    final int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        type = ErrorType.network;
        userMessage = '请求超时，请检查网络连接';
        severity = ErrorSeverity.medium;
        break;

      case DioExceptionType.connectionError:
        type = ErrorType.network;
        userMessage = '网络连接失败，请检查网络设置';
        severity = ErrorSeverity.medium;
        break;

      case DioExceptionType.badResponse:
        type = ErrorType.api;
        userMessage = _getMessageFromStatusCode(statusCode);
        severity = statusCode != null && statusCode >= 500
            ? ErrorSeverity.high
            : ErrorSeverity.medium;
        break;

      case DioExceptionType.cancel:
        type = ErrorType.unknown;
        userMessage = '请求已取消';
        severity = ErrorSeverity.low;
        break;

      default:
        type = ErrorType.unknown;
        userMessage = '网络请求失败，请稍后重试';
        severity = ErrorSeverity.medium;
        break;
    }

    return ErrorInfo(
      type: type,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      severity: severity,
      statusCode: statusCode,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: true,
      suggestedAction: '请稍后重试',
    );
  }

  /// Handle SocketException
  static ErrorInfo _handleSocketException(
    SocketException error,
    StackTrace? stackTrace,
  ) {
    return ErrorInfo(
      type: ErrorType.network,
      userMessage: '网络连接失败，请检查网络设置',
      technicalMessage: error.toString(),
      severity: ErrorSeverity.medium,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: true,
      suggestedAction: '请检查网络连接后重试',
    );
  }

  /// Handle FormatException
  static ErrorInfo _handleFormatException(
    FormatException error,
    StackTrace? stackTrace,
  ) {
    return ErrorInfo(
      type: ErrorType.api,
      userMessage: '数据格式错误',
      technicalMessage: error.toString(),
      severity: ErrorSeverity.high,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: false,
      suggestedAction: '请联系客服',
    );
  }

  /// Handle TypeError
  static ErrorInfo _handleTypeError(
    TypeError error,
    StackTrace? stackTrace,
  ) {
    return ErrorInfo(
      type: ErrorType.unknown,
      userMessage: '数据处理错误',
      technicalMessage: error.toString(),
      severity: ErrorSeverity.high,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: false,
      suggestedAction: '请联系客服',
    );
  }

  /// Handle unknown errors
  static ErrorInfo _handleUnknownError(
    dynamic error,
    StackTrace? stackTrace,
  ) {
    return ErrorInfo(
      type: ErrorType.unknown,
      userMessage: '发生未知错误，请稍后重试',
      technicalMessage: error.toString(),
      severity: ErrorSeverity.medium,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: true,
      suggestedAction: '请稍后重试',
    );
  }

  /// Get user message from HTTP status code
  static String _getMessageFromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '请求的资源不存在';
      case 429:
        return '请求过于频繁，请稍后重试';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务暂时不可用';
      case 504:
        return '网关超时';
      default:
        return '服务器错误，请稍后重试';
    }
  }

  /// Log error for debugging
  static void _logError(ErrorInfo errorInfo, String? context) {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔴 ERROR: ${errorInfo.type.name.toUpperCase()}');
      if (context != null) {
        debugPrint('📍 Context: $context');
      }
      debugPrint('📝 User Message: ${errorInfo.userMessage}');
      debugPrint('🔧 Technical: ${errorInfo.technicalMessage}');
      if (errorInfo.statusCode != null) {
        debugPrint('📊 Status Code: ${errorInfo.statusCode}');
      }
      if (errorInfo.apiCode != null) {
        debugPrint('📊 API Code: ${errorInfo.apiCode}');
      }
      debugPrint('⚠️ Severity: ${errorInfo.severity.name}');
      debugPrint('🔄 Recoverable: ${errorInfo.isRecoverable}');
      debugPrint('⏰ Timestamp: ${errorInfo.timestamp}');
      if (errorInfo.stackTrace != null) {
        debugPrint('📚 Stack Trace:');
        debugPrint(errorInfo.stackTrace.toString());
      }
      debugPrint('═══════════════════════════════════════════════════════════');
    }
  }

  // ============================================================
  // UI Display Methods
  // ============================================================

  /// Show error as a SnackBar
  ///
  /// [context] - BuildContext for showing SnackBar
  /// [errorInfo] - Error information to display
  /// [duration] - Duration to show the SnackBar
  /// [action] - Optional action button
  static void showSnackBar(
    BuildContext context,
    ErrorInfo errorInfo, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final snackBar = SnackBar(
      content: Text(errorInfo.userMessage),
      duration: duration,
      backgroundColor: _getColorForSeverity(errorInfo.severity),
      behavior: SnackBarBehavior.floating,
      action: action ??
          (errorInfo.isRecoverable && errorInfo.suggestedAction != null
              ? SnackBarAction(
                  label: '了解',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )
              : null),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Show error as a simple SnackBar with just the message
  ///
  /// [context] - BuildContext for showing SnackBar
  /// [message] - Error message to display
  /// [isError] - Whether this is an error (red) or warning (orange)
  static void showSimpleSnackBar(
    BuildContext context,
    String message, {
    bool isError = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      backgroundColor: isError ? Colors.red.shade700 : Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Show error as a dialog
  ///
  /// [context] - BuildContext for showing dialog
  /// [errorInfo] - Error information to display
  /// [onRetry] - Optional callback for retry action
  /// [onDismiss] - Optional callback when dialog is dismissed
  static Future<void> showErrorDialog(
    BuildContext context,
    ErrorInfo errorInfo, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getIconForType(errorInfo.type),
                color: _getColorForSeverity(errorInfo.severity),
              ),
              const SizedBox(width: 8),
              Text(_getTitleForType(errorInfo.type)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorInfo.userMessage),
              if (errorInfo.suggestedAction != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorInfo.suggestedAction!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDismiss?.call();
              },
              child: const Text('确定'),
            ),
            if (errorInfo.isRecoverable && onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onRetry();
                },
                child: const Text('重试'),
              ),
          ],
        );
      },
    );
  }

  /// Show a simple error dialog with just a message
  static Future<void> showSimpleErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDismiss?.call();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// Get color based on error severity
  static Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue.shade700;
      case ErrorSeverity.medium:
        return Colors.orange.shade700;
      case ErrorSeverity.high:
        return Colors.red.shade700;
      case ErrorSeverity.critical:
        return Colors.red.shade900;
    }
  }

  /// Get icon based on error type
  static IconData _getIconForType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.api:
        return Icons.cloud_off;
      case ErrorType.validation:
        return Icons.warning_amber;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.notFound:
        return Icons.search_off;
      case ErrorType.rateLimited:
        return Icons.speed;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  /// Get title based on error type
  static String _getTitleForType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return '网络错误';
      case ErrorType.api:
        return '服务错误';
      case ErrorType.validation:
        return '输入错误';
      case ErrorType.authentication:
        return '认证错误';
      case ErrorType.permission:
        return '权限错误';
      case ErrorType.notFound:
        return '未找到';
      case ErrorType.rateLimited:
        return '请求限制';
      case ErrorType.unknown:
        return '错误';
    }
  }

  // ============================================================
  // Convenience Methods
  // ============================================================

  /// Handle error and show SnackBar in one call
  ///
  /// [context] - BuildContext for showing SnackBar
  /// [error] - The exception to handle
  /// [stackTrace] - Optional stack trace
  /// [errorContext] - Optional context for additional error information
  static ErrorInfo handleAndShowSnackBar(
    BuildContext context,
    dynamic error, [
    StackTrace? stackTrace,
    String? errorContext,
  ]) {
    final errorInfo = handleError(error, stackTrace, errorContext);
    showSnackBar(context, errorInfo);
    return errorInfo;
  }

  /// Handle error and show dialog in one call
  ///
  /// [context] - BuildContext for showing dialog
  /// [error] - The exception to handle
  /// [stackTrace] - Optional stack trace
  /// [onRetry] - Optional callback for retry action
  /// [errorContext] - Optional context for additional error information
  static Future<ErrorInfo> handleAndShowDialog(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    VoidCallback? onRetry,
    String? errorContext,
  }) async {
    final errorInfo = handleError(error, stackTrace, errorContext);
    await showErrorDialog(context, errorInfo, onRetry: onRetry);
    return errorInfo;
  }

  /// Check if error is an authentication error
  static bool isAuthenticationError(dynamic error) {
    if (error is NetworkException) {
      return error.type == NetworkErrorType.unauthorized;
    }
    if (error is ApiException) {
      return error.code == 1008 || error.code == 401;
    }
    return false;
  }

  /// Check if error is a network connectivity error
  static bool isNetworkError(dynamic error) {
    if (error is NetworkException) {
      return error.type == NetworkErrorType.noConnection ||
          error.type == NetworkErrorType.timeout;
    }
    if (error is SocketException) {
      return true;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout;
    }
    return false;
  }

  /// Check if error is recoverable (can retry)
  static bool isRecoverableError(dynamic error) {
    final errorInfo = handleError(error);
    return errorInfo.isRecoverable;
  }
}
