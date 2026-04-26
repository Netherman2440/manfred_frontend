sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatSessionStartedStreamEvent extends ChatStreamEvent {
  const ChatSessionStartedStreamEvent({
    required this.sessionId,
    required this.agentId,
  });

  final String sessionId;
  final String agentId;
}

class ChatTextDeltaStreamEvent extends ChatStreamEvent {
  const ChatTextDeltaStreamEvent({required this.delta});

  final String delta;
}

class ChatDoneStreamEvent extends ChatStreamEvent {
  const ChatDoneStreamEvent();
}

class ChatErrorStreamEvent extends ChatStreamEvent {
  const ChatErrorStreamEvent({required this.error});

  final String error;
}
