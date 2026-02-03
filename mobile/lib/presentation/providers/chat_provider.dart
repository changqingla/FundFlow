import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/ai_repository_provider.dart';

/// Analysis type enum
enum AnalysisType {
  /// Standard analysis - comprehensive market analysis
  standard,

  /// Fast analysis - quick market overview
  fast,

  /// Deep research - AI agent with search capabilities
  deep,
}

/// Extended chat state with analysis support
class ChatStateExtended {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? currentResponse;
  final String? error;
  final String? statusMessage;
  final List<String> activeTools;
  final AnalysisType? currentAnalysisType;

  const ChatStateExtended({
    this.messages = const [],
    this.isLoading = false,
    this.currentResponse,
    this.error,
    this.statusMessage,
    this.activeTools = const [],
    this.currentAnalysisType,
  });

  ChatStateExtended copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentResponse,
    String? error,
    String? statusMessage,
    List<String>? activeTools,
    AnalysisType? currentAnalysisType,
    bool clearCurrentResponse = false,
    bool clearError = false,
    bool clearStatusMessage = false,
    bool clearAnalysisType = false,
  }) {
    return ChatStateExtended(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentResponse: clearCurrentResponse ? null : (currentResponse ?? this.currentResponse),
      error: clearError ? null : (error ?? this.error),
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      activeTools: activeTools ?? this.activeTools,
      currentAnalysisType: clearAnalysisType ? null : (currentAnalysisType ?? this.currentAnalysisType),
    );
  }

  /// Check if there's an ongoing streaming response
  bool get isStreaming => isLoading && currentResponse != null;

  /// Get the display message for current status
  String? get displayStatus {
    if (activeTools.isNotEmpty) {
      return '正在调用工具: ${activeTools.join(", ")}';
    }
    return statusMessage;
  }
}

/// Chat provider with full implementation
///
/// **Validates: Requirements 15.3**
final chatProvider = StateNotifierProvider<ChatNotifier, ChatStateExtended>(
  (ref) => ChatNotifier(ref),
);

/// Chat state notifier with SSE streaming support
///
/// Features:
/// - Multi-turn conversation history
/// - Streaming response handling
/// - Tool call status display
/// - Analysis mode support (standard/fast/deep)
///
/// **Validates: Requirements 15.3**
class ChatNotifier extends StateNotifier<ChatStateExtended> {
  final Ref _ref;
  StreamSubscription<ChatChunk>? _currentSubscription;

  ChatNotifier(this._ref) : super(const ChatStateExtended());

  /// Get the AI repository
  AIRepository get _aiRepository => _ref.read(aiRepositoryProvider);

  /// Send a message to the AI
  ///
  /// [message] - User message to send
  ///
  /// This method:
  /// 1. Adds the user message to history
  /// 2. Starts streaming the AI response
  /// 3. Updates state as chunks arrive
  /// 4. Completes the response when done
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Cancel any existing request
    _cancelCurrentRequest();

    // Add user message
    final userMessage = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      currentResponse: '',
      clearError: true,
      clearStatusMessage: true,
      activeTools: [],
    );

    try {
      // Get conversation history (excluding the message we just added)
      final history = state.messages.sublist(0, state.messages.length - 1);

      // Start streaming
      final stream = _aiRepository.chat(message, history);
      await _handleStream(stream);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        clearCurrentResponse: true,
      );
    }
  }

  /// Start standard analysis
  ///
  /// **Validates: Requirements 12.1**
  Future<void> startStandardAnalysis() async {
    await _startAnalysis(AnalysisType.standard);
  }

  /// Start fast analysis
  ///
  /// **Validates: Requirements 13.1**
  Future<void> startFastAnalysis() async {
    await _startAnalysis(AnalysisType.fast);
  }

  /// Start deep research
  ///
  /// **Validates: Requirements 14.1**
  Future<void> startDeepAnalysis() async {
    await _startAnalysis(AnalysisType.deep);
  }

  /// Internal method to start analysis
  Future<void> _startAnalysis(AnalysisType type) async {
    // Cancel any existing request
    _cancelCurrentRequest();

    // Add system message indicating analysis start
    final analysisName = _getAnalysisName(type);
    final systemMessage = ChatMessage(
      role: 'user',
      content: '开始$analysisName',
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, systemMessage],
      isLoading: true,
      currentResponse: '',
      currentAnalysisType: type,
      clearError: true,
      statusMessage: '正在准备$analysisName...',
      activeTools: [],
    );

    try {
      // Get the appropriate stream based on analysis type
      final Stream<ChatChunk> stream;
      switch (type) {
        case AnalysisType.standard:
          stream = _aiRepository.analyzeStandard();
          break;
        case AnalysisType.fast:
          stream = _aiRepository.analyzeFast();
          break;
        case AnalysisType.deep:
          stream = _aiRepository.analyzeDeep();
          break;
      }

      await _handleStream(stream);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        clearCurrentResponse: true,
        clearAnalysisType: true,
      );
    }
  }

  /// Get analysis name for display
  String _getAnalysisName(AnalysisType type) {
    switch (type) {
      case AnalysisType.standard:
        return '标准分析';
      case AnalysisType.fast:
        return '快速分析';
      case AnalysisType.deep:
        return '深度研究';
    }
  }

  /// Handle SSE stream
  Future<void> _handleStream(Stream<ChatChunk> stream) async {
    _currentSubscription = stream.listen(
      (chunk) => _handleChunk(chunk),
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.toString(),
          clearCurrentResponse: true,
          clearAnalysisType: true,
        );
      },
      onDone: () {
        // Stream completed - finalize response if needed
        _finalizeResponse();
      },
      cancelOnError: true,
    );

    // Wait for subscription to complete
    await _currentSubscription?.asFuture();
  }

  /// Handle a single chat chunk
  void _handleChunk(ChatChunk chunk) {
    switch (chunk.type) {
      case 'status':
        // Update status message
        state = state.copyWith(
          statusMessage: chunk.message,
        );
        break;

      case 'content':
        // Append content to current response
        if (chunk.chunk != null) {
          state = state.copyWith(
            currentResponse: (state.currentResponse ?? '') + chunk.chunk!,
            clearStatusMessage: true,
          );
        }
        break;

      case 'tool_call':
        // Update active tools
        state = state.copyWith(
          activeTools: chunk.tools,
          statusMessage: chunk.message,
        );
        break;

      case 'done':
        // Finalize the response
        _finalizeResponse();
        break;

      case 'error':
        // Handle error
        state = state.copyWith(
          isLoading: false,
          error: chunk.message ?? '未知错误',
          clearCurrentResponse: true,
          clearAnalysisType: true,
        );
        break;
    }
  }

  /// Finalize the current response
  void _finalizeResponse() {
    if (state.currentResponse != null && state.currentResponse!.isNotEmpty) {
      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: state.currentResponse!,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
        clearCurrentResponse: true,
        clearStatusMessage: true,
        activeTools: [],
        clearAnalysisType: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        clearCurrentResponse: true,
        clearStatusMessage: true,
        activeTools: [],
        clearAnalysisType: true,
      );
    }
  }

  /// Cancel the current request
  void _cancelCurrentRequest() {
    _currentSubscription?.cancel();
    _currentSubscription = null;
    _aiRepository.cancelCurrentRequest();
  }

  /// Stop the current streaming response
  void stopStreaming() {
    _cancelCurrentRequest();
    _finalizeResponse();
  }

  /// Clear chat history
  void clearHistory() {
    _cancelCurrentRequest();
    state = const ChatStateExtended();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _cancelCurrentRequest();
    super.dispose();
  }
}
