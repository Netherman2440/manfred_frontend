import '../domain/chat_mutation_result.dart';

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
