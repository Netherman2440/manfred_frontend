sealed class SessionItem {
  const SessionItem({
    required this.id,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String type;
  final DateTime createdAt;
}

class SessionMessageItem extends SessionItem {
  const SessionMessageItem({
    required super.id,
    required super.createdAt,
    required this.role,
    required this.content,
  }) : super(type: 'message');

  final String role;
  final String content;
}

class SessionToolCallItem extends SessionItem {
  const SessionToolCallItem({
    required super.id,
    required super.createdAt,
    required this.callId,
    required this.name,
    required this.arguments,
  }) : super(type: 'function_call');

  final String callId;
  final String name;
  final Object? arguments;
}

class SessionToolResultItem extends SessionItem {
  const SessionToolResultItem({
    required super.id,
    required super.createdAt,
    required this.callId,
    required this.name,
    required this.toolResult,
    required this.isError,
  }) : super(type: 'function_call_output');

  final String callId;
  final String name;
  final Object? toolResult;
  final bool isError;
}

class SessionReasoningItem extends SessionItem {
  const SessionReasoningItem({
    required super.id,
    required super.createdAt,
    required this.content,
  }) : super(type: 'reasoning');

  final String? content;
}
