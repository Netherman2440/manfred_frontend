class SessionListEntry {
  const SessionListEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.rootAgentId,
    required this.rootAgentName,
    required this.rootAgentStatus,
    required this.waitingForCount,
    required this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? title;
  final String status;
  final String rootAgentId;
  final String rootAgentName;
  final String rootAgentStatus;
  final int waitingForCount;
  final String? lastMessagePreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return 'Untitled session';
  }
}
