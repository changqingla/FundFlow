import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../local/local_storage_provider.dart';
import '../local/local_storage_service.dart';
import 'token_manager.dart';

/// Provider for the TokenManager singleton
///
/// The TokenManager handles:
/// - Secure token storage
/// - Token expiration checking
/// - Automatic token refresh before expiration
///
/// Usage:
/// ```dart
/// final tokenManager = ref.read(tokenManagerProvider);
/// await tokenManager.ensureValidToken();
/// ```
final tokenManagerProvider = Provider<TokenManager>((ref) {
  final storage = ref.watch(localStorageServiceProvider);

  // Create a separate Dio instance for token refresh
  // This avoids circular dependency with ApiClient
  final refreshDio = _createRefreshDio();

  final tokenManager = TokenManager(
    storage: storage,
    dio: refreshDio,
    onRefreshFailed: () {
      // This will be connected to auth provider to trigger logout
      _debugPrintRefreshFailed();
    },
    onTokensRefreshed: (tokenPair) {
      // Log successful refresh
      _debugPrintTokensRefreshed();
    },
  );

  return tokenManager;
});

/// Create a Dio instance specifically for token refresh requests
///
/// This is separate from the main ApiClient to avoid circular dependencies
/// and to ensure refresh requests don't get intercepted by auth middleware
Dio _createRefreshDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.requestTimeout),
      sendTimeout: Duration(seconds: AppConfig.requestTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
}

/// Debug print for refresh failed callback
void _debugPrintRefreshFailed() {
  // ignore: avoid_print
  print('[TokenManager] Token refresh failed - user needs to re-login');
}

/// Debug print for tokens refreshed callback
void _debugPrintTokensRefreshed() {
  // ignore: avoid_print
  print('[TokenManager] Tokens refreshed successfully');
}

/// Provider for token refresh state
///
/// This can be used to show loading indicators during token refresh
final tokenRefreshStateProvider = Provider<TokenRefreshState>((ref) {
  final tokenManager = ref.watch(tokenManagerProvider);
  return tokenManager.refreshState;
});

/// Provider for checking if user has valid tokens
final hasValidTokensProvider = Provider<bool>((ref) {
  final tokenManager = ref.watch(tokenManagerProvider);
  return tokenManager.hasTokens && !tokenManager.isTokenExpired;
});

/// Extension on Ref for convenient TokenManager access
extension TokenManagerRefExtension on Ref {
  /// Get the TokenManager instance
  TokenManager get tokenManager => read(tokenManagerProvider);
}

/// Extension on WidgetRef for convenient TokenManager access
extension TokenManagerWidgetRefExtension on WidgetRef {
  /// Get the TokenManager instance
  TokenManager get tokenManager => read(tokenManagerProvider);
}
