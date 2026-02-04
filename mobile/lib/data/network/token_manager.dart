import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_endpoints.dart';
import '../../core/config/app_config.dart';
import '../local/local_storage_service.dart';
import '../models/user.dart';

/// Token refresh state
enum TokenRefreshState {
  /// No refresh in progress
  idle,

  /// Token refresh is in progress
  refreshing,

  /// Token refresh failed
  failed,
}

/// Token Manager for handling secure token storage and automatic refresh
///
/// Features:
/// - Secure token storage using LocalStorageService
/// - Token expiration checking
/// - Automatic token refresh before expiration
/// - Configurable refresh threshold (default: 5 minutes before expiry)
/// - Thread-safe refresh mechanism (prevents multiple concurrent refreshes)
/// - Callback for handling refresh failures (trigger logout)
///
/// Usage:
/// ```dart
/// final tokenManager = TokenManager(
///   storage: localStorageService,
///   dio: dio,
///   onRefreshFailed: () => authProvider.logout(),
/// );
///
/// // Check and refresh token before making a request
/// await tokenManager.ensureValidToken();
///
/// // Get current access token
/// final token = tokenManager.accessToken;
/// ```
class TokenManager {
  final LocalStorageService _storage;
  final Dio _dio;

  /// Callback when token refresh fails (e.g., trigger logout)
  final VoidCallback? onRefreshFailed;

  /// Callback when tokens are successfully refreshed
  final void Function(TokenPair)? onTokensRefreshed;

  /// Current refresh state
  TokenRefreshState _refreshState = TokenRefreshState.idle;

  /// Completer for coordinating concurrent refresh requests
  Completer<bool>? _refreshCompleter;

  /// Lock to prevent concurrent refresh attempts
  bool _isRefreshing = false;

  TokenManager({
    required LocalStorageService storage,
    required Dio dio,
    this.onRefreshFailed,
    this.onTokensRefreshed,
  })  : _storage = storage,
        _dio = dio;

  /// Get current refresh state
  TokenRefreshState get refreshState => _refreshState;

  /// Check if a refresh is currently in progress
  bool get isRefreshing => _isRefreshing;

  // ============================================================
  // Token Access Methods
  // ============================================================

  /// Get the current access token
  String? get accessToken {
    if (!_storage.isInitialized) return null;
    return _storage.getAccessToken();
  }

  /// Get the current refresh token
  String? get refreshToken {
    if (!_storage.isInitialized) return null;
    return _storage.getRefreshToken();
  }

  /// Get the token expiration time
  DateTime? get tokenExpiresAt {
    if (!_storage.isInitialized) return null;
    return _storage.getTokenExpiresAt();
  }

  /// Check if user has valid tokens stored
  bool get hasTokens {
    final access = accessToken;
    final refresh = refreshToken;
    return access != null &&
        access.isNotEmpty &&
        refresh != null &&
        refresh.isNotEmpty;
  }

  /// Check if the current token is expired
  bool get isTokenExpired {
    if (!_storage.isInitialized) return true;
    return _storage.isTokenExpired();
  }

  /// Check if the token needs refresh (within threshold of expiry)
  bool get needsRefresh {
    final expiresAt = tokenExpiresAt;
    if (expiresAt == null) return true;

    final now = DateTime.now();
    const threshold = Duration(seconds: AppConfig.tokenRefreshThreshold);
    final refreshTime = expiresAt.subtract(threshold);

    return now.isAfter(refreshTime);
  }

  /// Get remaining time until token expires
  Duration? get timeUntilExpiry {
    final expiresAt = tokenExpiresAt;
    if (expiresAt == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;

    return expiresAt.difference(now);
  }

  // ============================================================
  // Token Storage Methods
  // ============================================================

  /// Save tokens after successful login or refresh
  ///
  /// [tokenPair] - The token pair containing access and refresh tokens
  Future<void> saveTokens(TokenPair tokenPair) async {
    if (!_storage.isInitialized) {
      throw StateError('LocalStorageService is not initialized');
    }

    // Calculate expiration time from expiresIn (seconds)
    final expiresAt = DateTime.now().add(
      Duration(seconds: tokenPair.expiresIn),
    );

    await Future.wait([
      _storage.saveAccessToken(tokenPair.accessToken),
      _storage.saveRefreshToken(tokenPair.refreshToken),
      _storage.saveTokenExpiresAt(expiresAt),
    ]);

    _debugLog('Tokens saved, expires at: $expiresAt');
  }

  /// Clear all stored tokens (on logout)
  Future<void> clearTokens() async {
    if (!_storage.isInitialized) return;

    await _storage.clearAuthData();
    _refreshState = TokenRefreshState.idle;
    _debugLog('Tokens cleared');
  }

  // ============================================================
  // Token Refresh Methods
  // ============================================================

  /// Ensure the token is valid before making a request
  ///
  /// This method will:
  /// 1. Check if token needs refresh
  /// 2. If yes, attempt to refresh the token
  /// 3. Return true if token is valid, false otherwise
  ///
  /// Returns `true` if token is valid (or was successfully refreshed)
  /// Returns `false` if token refresh failed
  Future<bool> ensureValidToken() async {
    // No tokens stored - user needs to login
    if (!hasTokens) {
      _debugLog('No tokens stored');
      return false;
    }

    // Token is still valid and doesn't need refresh
    if (!needsRefresh) {
      return true;
    }

    // Token needs refresh
    _debugLog('Token needs refresh');
    return await _refreshTokens();
  }

  /// Refresh the access token using the refresh token
  ///
  /// This method is thread-safe and will only allow one refresh at a time.
  /// Concurrent calls will wait for the ongoing refresh to complete.
  Future<bool> _refreshTokens() async {
    // If already refreshing, wait for the current refresh to complete
    if (_isRefreshing && _refreshCompleter != null) {
      _debugLog('Waiting for ongoing refresh');
      return await _refreshCompleter!.future;
    }

    // Start new refresh
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    _refreshState = TokenRefreshState.refreshing;

    try {
      final currentRefreshToken = refreshToken;
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _debugLog('No refresh token available');
        _handleRefreshFailure();
        return false;
      }

      _debugLog('Refreshing token...');

      // Make refresh token request
      final response = await _dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': currentRefreshToken},
        options: Options(
          // Don't add auth header for refresh request
          headers: {'Content-Type': 'application/json'},
        ),
      );

      // Parse response
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      final code = data['code'] as int? ?? -1;
      if (code != 0) {
        final message = data['message'] as String? ?? 'Token refresh failed';
        throw Exception(message);
      }

      final tokenData = data['data'] as Map<String, dynamic>?;
      if (tokenData == null) {
        throw Exception('No token data in response');
      }

      // Parse and save new tokens
      final newTokenPair = TokenPair.fromJson(tokenData);
      await saveTokens(newTokenPair);

      _refreshState = TokenRefreshState.idle;
      _debugLog('Token refreshed successfully');

      // Notify listeners
      onTokensRefreshed?.call(newTokenPair);

      _refreshCompleter?.complete(true);
      return true;
    } on DioException catch (e) {
      _debugLog('Token refresh failed (DioException): ${e.message}');

      // Check if it's an auth error (refresh token expired)
      if (e.response?.statusCode == 401) {
        _handleRefreshFailure();
      } else {
        // Network error - might be temporary
        _refreshState = TokenRefreshState.failed;
      }

      _refreshCompleter?.complete(false);
      return false;
    } catch (e) {
      _debugLog('Token refresh failed: $e');
      _handleRefreshFailure();
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Handle refresh failure - clear tokens and notify
  void _handleRefreshFailure() {
    _refreshState = TokenRefreshState.failed;
    _debugLog('Refresh failed, triggering logout');

    // Clear tokens
    clearTokens();

    // Notify callback (e.g., trigger logout)
    onRefreshFailed?.call();
  }

  /// Force refresh the token (even if not expired)
  ///
  /// Useful for testing or when server indicates token is invalid
  Future<bool> forceRefresh() async {
    if (!hasTokens) return false;
    return await _refreshTokens();
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Debug logging helper
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[TokenManager] $message');
    }
  }

  /// Get token status for debugging
  Map<String, dynamic> getTokenStatus() {
    return {
      'hasTokens': hasTokens,
      'isExpired': isTokenExpired,
      'needsRefresh': needsRefresh,
      'expiresAt': tokenExpiresAt?.toIso8601String(),
      'timeUntilExpiry': timeUntilExpiry?.inSeconds,
      'refreshState': _refreshState.name,
      'isRefreshing': _isRefreshing,
    };
  }
}
