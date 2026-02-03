/// Application configuration for the Fund Investment Analyzer app.
///
/// This class provides centralized configuration management for:
/// - API endpoints (development/production)
/// - Network timeouts and retry settings
/// - Cache expiration policies
/// - Token management settings
///
/// Usage:
/// ```dart
/// final baseUrl = AppConfig.apiBaseUrl;
/// final timeout = AppConfig.requestTimeout;
/// ```
class AppConfig {
  AppConfig._();

  // ============================================================
  // Environment Configuration
  // ============================================================

  /// API base URL for development environment
  static const String devApiBaseUrl = 'http://localhost:8080/api/v1';

  /// API base URL for production environment
  static const String prodApiBaseUrl = 'https://api.example.com/api/v1';

  /// Whether the app is running in production mode.
  /// This is determined by the Dart VM environment.
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  /// Get the current API base URL based on environment
  static String get apiBaseUrl => isProduction ? prodApiBaseUrl : devApiBaseUrl;

  /// Get the current environment name for debugging/logging
  static String get environmentName => isProduction ? 'production' : 'development';

  // ============================================================
  // Network Configuration
  // ============================================================

  /// Connection timeout in seconds (time to establish connection)
  static const int connectTimeout = 15;

  /// Request timeout in seconds (time to complete request)
  static const int requestTimeout = 30;

  /// SSE (Server-Sent Events) connection timeout in seconds
  /// Used for AI chat streaming responses
  static const int sseTimeout = 120;

  /// Maximum number of retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Base delay between retry attempts in milliseconds
  static const int retryBaseDelayMs = 1000;

  // ============================================================
  // Authentication Configuration
  // ============================================================

  /// Token refresh threshold in seconds.
  /// Token will be refreshed when less than this time remaining before expiry.
  static const int tokenRefreshThreshold = 300; // 5 minutes

  /// Access token expiry duration (should match backend configuration)
  static const Duration accessTokenExpiry = Duration(days: 7);

  /// Secure storage key for access token
  static const String accessTokenKey = 'access_token';

  /// Secure storage key for refresh token
  static const String refreshTokenKey = 'refresh_token';

  // ============================================================
  // Cache Configuration
  // ============================================================

  /// Cache expiration for market index data (real-time data, short TTL)
  static const Duration marketDataCacheExpiry = Duration(seconds: 30);

  /// Cache expiration for precious metals data
  static const Duration preciousMetalsCacheExpiry = Duration(seconds: 30);

  /// Cache expiration for sector/industry data
  static const Duration sectorDataCacheExpiry = Duration(minutes: 5);

  /// Cache expiration for news flash data
  static const Duration newsDataCacheExpiry = Duration(minutes: 1);

  /// Cache expiration for fund basic information
  static const Duration fundInfoCacheExpiry = Duration(hours: 1);

  /// Cache expiration for fund valuation data (real-time, short TTL)
  static const Duration fundValuationCacheExpiry = Duration(seconds: 30);

  /// Cache expiration for gold history data
  static const Duration goldHistoryCacheExpiry = Duration(hours: 1);

  // ============================================================
  // Pagination Configuration
  // ============================================================

  /// Default page size for list requests
  static const int defaultPageSize = 20;

  /// Maximum page size allowed
  static const int maxPageSize = 100;

  // ============================================================
  // App Information
  // ============================================================

  /// Application name
  static const String appName = 'Fund Investment Analyzer';

  /// Application version (should be updated with each release)
  static const String appVersion = '1.0.0';

  /// Minimum supported backend API version
  static const String minApiVersion = '1.0.0';
}
