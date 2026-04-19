class ChatMutationResult {
  const ChatMutationResult({
    required this.sessionId,
    required this.agentId,
    required this.status,
    required this.error,
  });

  final String sessionId;
  final String agentId;
  final String status;
  final String? error;
}
