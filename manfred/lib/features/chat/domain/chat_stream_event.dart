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

class ChatTextDoneStreamEvent extends ChatStreamEvent {
  const ChatTextDoneStreamEvent({required this.text});

  final String text;
}

class ChatFunctionCallDeltaStreamEvent extends ChatStreamEvent {
  const ChatFunctionCallDeltaStreamEvent({
    required this.callId,
    required this.name,
    required this.argumentsDelta,
  });

  final String callId;
  final String name;
  final String argumentsDelta;
}

class ChatFunctionCallDoneStreamEvent extends ChatStreamEvent {
  const ChatFunctionCallDoneStreamEvent({
    required this.callId,
    required this.name,
    required this.arguments,
  });

  final String callId;
  final String name;
  final Object? arguments;
}

class ChatDoneStreamEvent extends ChatStreamEvent {
  const ChatDoneStreamEvent();
}

class ChatErrorStreamEvent extends ChatStreamEvent {
  const ChatErrorStreamEvent({required this.error});

  final String error;
}
