import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../local/local_storage_service.dart';
import '../models/api_response.dart';
import 'token_manager.dart';

/// Network error types for categorizing different failure scenarios
enum NetworkErrorType {
  /// Connection timeout - failed to establish connection
  timeout,

  /// No internet connection
  noConnection,

  /// Server returned an error (5xx)
  serverError,

  /// Unauthorized - token invalid or expired (401)
  unauthorized,

  /// Rate limited - too many requests (429)
  rateLimited,

  /// Bad request - invalid request data (400)
  badRequest,

  /// Not found - resource doesn't exist (404)
  notFound,

  /// Unknown error
  unknown,
}

/// Custom exception for network errors
class NetworkException implements Exception {
  final NetworkErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  NetworkException({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'NetworkException: $message (type: $type, code: $statusCode)';

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case NetworkErrorType.timeout:
        return '请求超时，请检查网络连接';
      case NetworkErrorType.noConnection:
        return '网络连接失败，请检查网络设置';
      case NetworkErrorType.serverError:
        return '服务器错误，请稍后重试';
      case NetworkErrorType.unauthorized:
        return '登录已过期，请重新登录';
      case NetworkErrorType.rateLimited:
        return '请求过于频繁，请稍后重试';
      case NetworkErrorType.badRequest:
        return '请求参数错误';
      case NetworkErrorType.notFound:
        return '请求的资源不存在';
      case NetworkErrorType.unknown:
        return '未知错误，请稍后重试';
    }
  }
}

/// API response error from server
class ApiException implements Exception {
  final int code;
  final String message;

  ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException: $message (code: $code)';
}

/// API Client for making HTTP requests to the backend
///
/// Features:
/// - Dio HTTP client with configurable timeouts
/// - Request interceptor for adding auth token
/// - Response interceptor for error handling
/// - Logging interceptor for debugging
/// - Automatic token injection
/// - Automatic token refresh via TokenManager
/// - Unified error handling
class ApiClient {
  late final Dio _dio;
  final LocalStorageService _storage;
  TokenManager? _tokenManager;

  /// Callback for handling unauthorized responses (token expired)
  /// This can be used to trigger logout or token refresh
  void Function()? onUnauthorized;

  ApiClient({
    required LocalStorageService storage,
    this.onUnauthorized,
  }) : _storage = storage {
    _dio = _createDio();
    _setupInterceptors();
  }

  /// Set the TokenManager for automatic token refresh
  ///
  /// This should be called after both ApiClient and TokenManager are created
  /// to avoid circular dependencies
  void setTokenManager(TokenManager tokenManager) {
    _tokenManager = tokenManager;
  }

  /// Get the TokenManager instance
  TokenManager? get tokenManager => _tokenManager;

  /// Create and configure Dio instance
  Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: AppConfig.requestTimeout),
        sendTimeout: const Duration(seconds: AppConfig.requestTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Setup request/response interceptors
  void _setupInterceptors() {
    // Auth interceptor - adds token to requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Logging interceptor (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }
  }

  /// Request interceptor - adds auth token to headers
  void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token handling for auth endpoints that don't need it
    if (_isAuthEndpoint(options.path)) {
      handler.next(options);
      return;
    }

    // Try to ensure valid token using TokenManager
    if (_tokenManager != null) {
      try {
        final isValid = await _tokenManager!.ensureValidToken();
        if (!isValid && _tokenManager!.hasTokens) {
          // Token refresh failed - let the request proceed
          // The server will return 401 and trigger onUnauthorized
          debugPrint('[ApiClient] Token validation failed, proceeding with request');
        }
      } catch (e) {
        debugPrint('[ApiClient] Error during token validation: $e');
      }
    }

    // Add auth token if available
    if (_storage.isInitialized) {
      final token = _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  /// Check if the endpoint is an auth endpoint that doesn't need token refresh
  bool _isAuthEndpoint(String path) {
    const authEndpoints = [
      '/auth/login',
      '/auth/register',
      '/auth/verify-email',
      '/auth/refresh',
      '/auth/forgot-password',
      '/auth/reset-password',
    ];
    return authEndpoints.any((endpoint) => path.contains(endpoint));
  }

  /// Response interceptor - handles successful responses
  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  /// Error interceptor - transforms errors into NetworkException
  void _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    final networkException = _transformError(error);

    // Handle unauthorized errors
    if (networkException.type == NetworkErrorType.unauthorized) {
      onUnauthorized?.call();
    }

    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        error: networkException,
        type: error.type,
        response: error.response,
      ),
    );
  }

  /// Transform DioException to NetworkException
  NetworkException _transformError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          type: NetworkErrorType.timeout,
          message: 'Request timeout',
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          type: NetworkErrorType.noConnection,
          message: 'No internet connection',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return NetworkException(
          type: NetworkErrorType.unknown,
          message: 'Request cancelled',
          originalError: error,
        );

      default:
        return NetworkException(
          type: NetworkErrorType.unknown,
          message: error.message ?? 'Unknown error',
          originalError: error,
        );
    }
  }

  /// Handle bad response errors based on status code
  NetworkException _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    // Try to extract error message from response
    String message = 'Server error';
    if (responseData is Map<String, dynamic>) {
      message = responseData['message'] as String? ?? message;
    }

    switch (statusCode) {
      case 400:
        return NetworkException(
          type: NetworkErrorType.badRequest,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );

      case 401:
        return NetworkException(
          type: NetworkErrorType.unauthorized,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );

      case 404:
        return NetworkException(
          type: NetworkErrorType.notFound,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );

      case 429:
        return NetworkException(
          type: NetworkErrorType.rateLimited,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return NetworkException(
          type: NetworkErrorType.serverError,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );

      default:
        return NetworkException(
          type: NetworkErrorType.unknown,
          message: message,
          statusCode: statusCode,
          originalError: error,
        );
    }
  }

  // ============================================================
  // HTTP Methods
  // ============================================================

  /// Perform a GET request
  ///
  /// [path] - API endpoint path
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractNetworkException(e);
    }
  }

  /// Perform a POST request
  ///
  /// [path] - API endpoint path
  /// [data] - Request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractNetworkException(e);
    }
  }

  /// Perform a PUT request
  ///
  /// [path] - API endpoint path
  /// [data] - Request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractNetworkException(e);
    }
  }

  /// Perform a DELETE request
  ///
  /// [path] - API endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractNetworkException(e);
    }
  }

  /// Perform a PATCH request
  ///
  /// [path] - API endpoint path
  /// [data] - Request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _extractNetworkException(e);
    }
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  /// Extract NetworkException from DioException
  NetworkException _extractNetworkException(DioException e) {
    if (e.error is NetworkException) {
      return e.error as NetworkException;
    }
    return _transformError(e);
  }

  /// Parse API response and check for errors
  ///
  /// Throws [ApiException] if the response indicates an error
  T parseResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException(code: -1, message: 'Invalid response format');
    }

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json as Map<String, dynamic>,
    );

    if (apiResponse.hasError) {
      throw ApiException(
        code: apiResponse.code,
        message: apiResponse.message,
      );
    }

    if (apiResponse.data == null) {
      throw ApiException(code: -1, message: 'Response data is null');
    }

    return fromJson(apiResponse.data!);
  }

  /// Parse API response for list data
  List<T> parseListResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException(code: -1, message: 'Invalid response format');
    }

    final code = data['code'] as int? ?? -1;
    final message = data['message'] as String? ?? 'Unknown error';

    if (code != 0) {
      throw ApiException(code: code, message: message);
    }

    final responseData = data['data'];
    if (responseData == null) {
      return [];
    }

    if (responseData is! List) {
      throw ApiException(code: -1, message: 'Expected list response');
    }

    return responseData
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parse API response without data (for operations like delete)
  void parseEmptyResponse(Response response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException(code: -1, message: 'Invalid response format');
    }

    final code = data['code'] as int? ?? -1;
    final message = data['message'] as String? ?? 'Unknown error';

    if (code != 0) {
      throw ApiException(code: code, message: message);
    }
  }

  /// Get the underlying Dio instance for advanced usage
  /// (e.g., for SSE streaming)
  Dio get dio => _dio;

  /// Update the base URL (useful for environment switching)
  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }
}
