import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../models/chat.dart';

/// SSE (Server-Sent Events) event types
enum SSEEventType {
  /// Status update (e.g., "正在获取数据...")
  status,

  /// Content chunk from AI response
  content,

  /// Tool call notification (e.g., search, fetch)
  toolCall,

  /// Stream completed successfully
  done,

  /// Error occurred during streaming
  error,
}

/// Extension to convert string to SSEEventType
extension SSEEventTypeExtension on String {
  SSEEventType toSSEEventType() {
    switch (this) {
      case 'status':
        return SSEEventType.status;
      case 'content':
        return SSEEventType.content;
      case 'tool_call':
        return SSEEventType.toolCall;
      case 'done':
        return SSEEventType.done;
      case 'error':
        return SSEEventType.error;
      default:
        return SSEEventType.content;
    }
  }
}

/// SSE event data structure
class SSEEvent {
  /// Event type
  final SSEEventType type;

  /// Event data (parsed from JSON)
  final ChatChunk data;

  /// Raw event string (for debugging)
  final String? rawData;

  SSEEvent({
    required this.type,
    required this.data,
    this.rawData,
  });

  /// Check if this is a terminal event (done or error)
  bool get isTerminal =>
      type == SSEEventType.done || type == SSEEventType.error;

  @override
  String toString() => 'SSEEvent(type: $type, data: $data)';
}

/// SSE connection state
enum SSEConnectionState {
  /// Not connected
  disconnected,

  /// Connecting to server
  connecting,

  /// Connected and receiving events
  connected,

  /// Connection closed normally
  closed,

  /// Connection failed with error
  error,
}

/// SSE Client for handling Server-Sent Events streaming responses
///
/// This client is designed for AI chat streaming responses and supports:
/// - Connection to SSE endpoint using Dio
/// - Stream parsing for SSE events (data: lines)
/// - Handling of different event types (status, content, tool_call, done, error)
/// - Connection timeout handling
/// - Cancellation support
/// - Graceful error handling
///
/// **Validates: Requirements 12.4, 15.4**
///
/// Usage:
/// ```dart
/// final sseClient = SSEClient(dio: apiClient.dio);
/// final stream = sseClient.connect(
///   '/ai/chat',
///   data: {'message': 'Hello'},
/// );
///
/// await for (final event in stream) {
///   if (event.type == SSEEventType.content) {
///     print(event.data.chunk);
///   }
/// }
/// ```
class SSEClient {
  final Dio _dio;
  final Duration _timeout;

  /// Current connection state
  SSEConnectionState _state = SSEConnectionState.disconnected;

  /// Get current connection state
  SSEConnectionState get state => _state;

  /// Cancel token for the current connection
  CancelToken? _cancelToken;

  /// Create an SSE client
  ///
  /// [dio] - Dio instance (typically from ApiClient)
  /// [timeout] - Connection timeout (defaults to AppConfig.sseTimeout)
  SSEClient({
    required Dio dio,
    Duration? timeout,
  })  : _dio = dio,
        _timeout = timeout ?? Duration(seconds: AppConfig.sseTimeout);

  /// Connect to an SSE endpoint and return a stream of events
  ///
  /// [path] - API endpoint path (e.g., '/ai/chat')
  /// [data] - Request body data (for POST requests)
  /// [queryParameters] - Optional query parameters
  /// [headers] - Additional headers
  ///
  /// Returns a [Stream] of [SSEEvent] objects
  ///
  /// The stream will emit events until:
  /// - A 'done' event is received
  /// - An 'error' event is received
  /// - The connection is cancelled
  /// - A network error occurs
  Stream<SSEEvent> connect(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async* {
    _state = SSEConnectionState.connecting;
    _cancelToken = CancelToken();

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            ...?headers,
          },
          responseType: ResponseType.stream,
          receiveTimeout: _timeout,
        ),
        cancelToken: _cancelToken,
      );

      _state = SSEConnectionState.connected;

      // Parse the SSE stream
      yield* _parseSSEStream(response.data!.stream);

      _state = SSEConnectionState.closed;
    } on DioException catch (e) {
      _state = SSEConnectionState.error;

      if (e.type == DioExceptionType.cancel) {
        // Connection was cancelled, emit done event
        yield SSEEvent(
          type: SSEEventType.done,
          data: const ChatChunk(type: 'done', message: 'Connection cancelled'),
        );
      } else {
        // Emit error event
        yield SSEEvent(
          type: SSEEventType.error,
          data: ChatChunk(
            type: 'error',
            message: _getErrorMessage(e),
          ),
        );
      }
    } catch (e) {
      _state = SSEConnectionState.error;

      yield SSEEvent(
        type: SSEEventType.error,
        data: ChatChunk(
          type: 'error',
          message: e.toString(),
        ),
      );
    }
  }

  /// Parse SSE stream from response body
  Stream<SSEEvent> _parseSSEStream(Stream<List<int>> stream) async* {
    final buffer = StringBuffer();

    await for (final chunk in stream.transform(utf8.decoder)) {
      buffer.write(chunk);

      // Process complete lines
      final content = buffer.toString();
      final lines = content.split('\n');

      // Keep the last incomplete line in buffer
      buffer.clear();
      if (!content.endsWith('\n')) {
        buffer.write(lines.removeLast());
      }

      for (final line in lines) {
        final event = _parseLine(line);
        if (event != null) {
          yield event;

          // Stop if terminal event
          if (event.isTerminal) {
            return;
          }
        }
      }
    }

    // Process any remaining content in buffer
    if (buffer.isNotEmpty) {
      final event = _parseLine(buffer.toString());
      if (event != null) {
        yield event;
      }
    }
  }

  /// Parse a single SSE line
  ///
  /// SSE format:
  /// ```
  /// data: {"type": "content", "chunk": "Hello"}
  /// ```
  SSEEvent? _parseLine(String line) {
    final trimmed = line.trim();

    // Skip empty lines and comments
    if (trimmed.isEmpty || trimmed.startsWith(':')) {
      return null;
    }

    // Parse data: prefix
    if (trimmed.startsWith('data:')) {
      final jsonStr = trimmed.substring(5).trim();

      if (jsonStr.isEmpty) {
        return null;
      }

      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final chatChunk = ChatChunk.fromJson(json);

        return SSEEvent(
          type: chatChunk.type.toSSEEventType(),
          data: chatChunk,
          rawData: jsonStr,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SSE] Failed to parse JSON: $jsonStr, error: $e');
        }

        // Return as content if JSON parsing fails
        return SSEEvent(
          type: SSEEventType.content,
          data: ChatChunk(type: 'content', chunk: jsonStr),
          rawData: jsonStr,
        );
      }
    }

    // Handle event: prefix (optional in SSE)
    if (trimmed.startsWith('event:')) {
      // Event type is handled in the data line
      return null;
    }

    // Handle id: prefix (optional in SSE)
    if (trimmed.startsWith('id:')) {
      // Event ID is not used in our implementation
      return null;
    }

    // Handle retry: prefix (optional in SSE)
    if (trimmed.startsWith('retry:')) {
      // Retry interval is not used in our implementation
      return null;
    }

    return null;
  }

  /// Get user-friendly error message from DioException
  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络连接';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return '登录已过期，请重新登录';
        } else if (statusCode == 429) {
          return '请求过于频繁，请稍后重试';
        } else if (statusCode != null && statusCode >= 500) {
          return '服务器错误，请稍后重试';
        }
        return '请求失败: ${e.response?.statusMessage ?? "未知错误"}';
      default:
        return e.message ?? '未知错误';
    }
  }

  /// Cancel the current SSE connection
  ///
  /// This will cause the stream to emit a 'done' event and close
  void cancel() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
    _state = SSEConnectionState.disconnected;
  }

  /// Check if currently connected
  bool get isConnected => _state == SSEConnectionState.connected;

  /// Check if connection is in progress
  bool get isConnecting => _state == SSEConnectionState.connecting;
}

/// SSE Client Provider for dependency injection
///
/// Creates an SSE client from an existing Dio instance
class SSEClientFactory {
  final Dio _dio;

  SSEClientFactory({required Dio dio}) : _dio = dio;

  /// Create a new SSE client instance
  SSEClient create({Duration? timeout}) {
    return SSEClient(dio: _dio, timeout: timeout);
  }
}
