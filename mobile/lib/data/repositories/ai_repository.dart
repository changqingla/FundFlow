import 'dart:async';

import '../models/chat.dart';
import '../network/api_client.dart';
import '../network/sse_client.dart';
import '../../core/config/api_endpoints.dart';

/// AI repository interface
///
/// **Validates: Requirements 12.1, 13.1, 14.1, 15.1**
abstract class AIRepository {
  /// Chat with AI (SSE streaming)
  ///
  /// [message] - User message to send
  /// [history] - Previous conversation history for context
  ///
  /// Returns a stream of [ChatChunk] objects representing the AI response
  Stream<ChatChunk> chat(String message, List<ChatMessage> history);

  /// Standard analysis (SSE streaming)
  ///
  /// Generates a comprehensive market analysis report including:
  /// - Market trends
  /// - Sector opportunities
  /// - Fund portfolio suggestions
  /// - Risk warnings
  ///
  /// **Validates: Requirements 12.1**
  Stream<ChatChunk> analyzeStandard();

  /// Fast analysis (SSE streaming)
  ///
  /// Generates a concise market analysis report
  /// Uses single LLM call for quick response
  ///
  /// **Validates: Requirements 13.1**
  Stream<ChatChunk> analyzeFast();

  /// Deep research (SSE streaming)
  ///
  /// Uses ReAct Agent to autonomously search news and fetch web content
  /// Generates detailed research report
  ///
  /// **Validates: Requirements 14.1**
  Stream<ChatChunk> analyzeDeep();

  /// Cancel any ongoing SSE connection
  void cancelCurrentRequest();
}

/// Implementation of AIRepository using SSE client
///
/// This implementation uses Server-Sent Events (SSE) for streaming
/// AI responses from the backend.
///
/// **Validates: Requirements 12.1, 13.1, 14.1, 15.1**
class AIRepositoryImpl implements AIRepository {
  final ApiClient _apiClient;
  SSEClient? _currentSSEClient;

  AIRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Stream<ChatChunk> chat(String message, List<ChatMessage> history) async* {
    // Cancel any existing request
    cancelCurrentRequest();

    // Create new SSE client
    _currentSSEClient = SSEClient(dio: _apiClient.dio);

    // Prepare request data
    final requestData = ChatRequest(
      message: message,
      history: history,
    ).toJson();

    // Connect to SSE endpoint
    await for (final event in _currentSSEClient!.connect(
      ApiEndpoints.aiChat,
      data: requestData,
    )) {
      yield event.data;

      // Stop if terminal event
      if (event.isTerminal) {
        break;
      }
    }

    _currentSSEClient = null;
  }

  @override
  Stream<ChatChunk> analyzeStandard() async* {
    yield* _analyzeWithEndpoint(ApiEndpoints.aiAnalyzeStandard);
  }

  @override
  Stream<ChatChunk> analyzeFast() async* {
    yield* _analyzeWithEndpoint(ApiEndpoints.aiAnalyzeFast);
  }

  @override
  Stream<ChatChunk> analyzeDeep() async* {
    yield* _analyzeWithEndpoint(ApiEndpoints.aiAnalyzeDeep);
  }

  /// Internal method to perform analysis with a specific endpoint
  Stream<ChatChunk> _analyzeWithEndpoint(String endpoint) async* {
    // Cancel any existing request
    cancelCurrentRequest();

    // Create new SSE client
    _currentSSEClient = SSEClient(dio: _apiClient.dio);

    // Connect to SSE endpoint (no request body needed for analysis)
    await for (final event in _currentSSEClient!.connect(endpoint)) {
      yield event.data;

      // Stop if terminal event
      if (event.isTerminal) {
        break;
      }
    }

    _currentSSEClient = null;
  }

  @override
  void cancelCurrentRequest() {
    _currentSSEClient?.cancel();
    _currentSSEClient = null;
  }
}
