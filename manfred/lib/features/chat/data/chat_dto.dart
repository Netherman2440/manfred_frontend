import '../domain/chat_mutation_result.dart';
import '../domain/queued_message.dart';

class ChatMutationResultDto {
  const ChatMutationResultDto({
    required this.sessionId,
    required this.agentId,
    required this.status,
    required this.error,
  });

  final String sessionId;
  final String agentId;
  final String status;
  final String? error;

  factory ChatMutationResultDto.fromJson(Map<String, dynamic> json) {
    return ChatMutationResultDto(
      sessionId: json['session_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      error: json['error'] as String?,
    );
  }

  ChatMutationResult toDomain() {
    return ChatMutationResult(
      sessionId: sessionId,
      agentId: agentId,
      status: status,
      error: error,
    );
  }
}

class QueueMessageResultDto {
  const QueueMessageResultDto({
    required this.queuedInputId,
    required this.position,
  });

  final String queuedInputId;
  final int? position;

  factory QueueMessageResultDto.fromJson(Map<String, dynamic> json) {
    final rawPosition = json['position'];
    return QueueMessageResultDto(
      queuedInputId: json['queued_input_id'] as String? ?? '',
      position: rawPosition is num ? rawPosition.toInt() : null,
    );
  }

  QueuedMessage applyTo(QueuedMessage message) {
    return message.copyWith(
      queuedInputId: queuedInputId.isEmpty ? null : queuedInputId,
      position: position,
    );
  }
}
