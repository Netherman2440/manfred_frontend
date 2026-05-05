import 'session_attachment.dart';

sealed class SessionItem {
  const SessionItem({
    required this.id,
    required this.type,
    required this.agentId,
    required this.sequence,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String agentId;
  final int sequence;
  final DateTime createdAt;
}

class SessionMessageItem extends SessionItem {
  const SessionMessageItem({
    required super.id,
    required super.agentId,
    required super.sequence,
    required super.createdAt,
    required this.role,
    required this.content,
    this.attachments = const <SessionAttachment>[],
    this.isEdited = false,
    this.editedAt,
    this.pendingStatus,
  }) : super(type: 'message');

  final String role;
  final String content;
  final List<SessionAttachment> attachments;
  final bool isEdited;
  final DateTime? editedAt;
  final String? pendingStatus;

  SessionMessageItem copyWith({
    String? id,
    String? agentId,
    int? sequence,
    DateTime? createdAt,
    String? role,
    String? content,
    List<SessionAttachment>? attachments,
    bool? isEdited,
    DateTime? editedAt,
    String? pendingStatus,
    bool clearEditedAt = false,
    bool clearPendingStatus = false,
  }) {
    return SessionMessageItem(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      sequence: sequence ?? this.sequence,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      isEdited: isEdited ?? this.isEdited,
      editedAt: clearEditedAt ? null : editedAt ?? this.editedAt,
      pendingStatus: clearPendingStatus
          ? null
          : pendingStatus ?? this.pendingStatus,
    );
  }
}

class SessionToolCallItem extends SessionItem {
  const SessionToolCallItem({
    required super.id,
    required super.agentId,
    required super.sequence,
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
    required super.agentId,
    required super.sequence,
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
    required super.agentId,
    required super.sequence,
    required super.createdAt,
    required this.content,
  }) : super(type: 'reasoning');

  final String? content;
}
