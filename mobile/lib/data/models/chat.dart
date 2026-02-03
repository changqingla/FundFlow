/// Chat message data model
class ChatMessage {
  final String role; // user/assistant
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Chat request data model
class ChatRequest {
  final String message;
  final List<ChatMessage> history;

  const ChatRequest({
    required this.message,
    this.history = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'history': history.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList(),
    };
  }
}

/// Chat chunk data model (for SSE streaming)
class ChatChunk {
  final String type; // status/content/tool_call/done/error
  final String? message;
  final String? chunk;
  final List<String> tools;

  const ChatChunk({
    required this.type,
    this.message,
    this.chunk,
    this.tools = const [],
  });

  factory ChatChunk.fromJson(Map<String, dynamic> json) {
    return ChatChunk(
      type: json['type'] as String,
      message: json['message'] as String?,
      chunk: json['chunk'] as String?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (message != null) 'message': message,
      if (chunk != null) 'chunk': chunk,
      'tools': tools,
    };
  }
}

/// Chat state data model
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? currentResponse;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentResponse,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentResponse,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentResponse: currentResponse ?? this.currentResponse,
      error: error ?? this.error,
    );
  }
}
