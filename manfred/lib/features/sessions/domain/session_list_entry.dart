import 'session_title_formatter.dart';

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

    return formatSessionTitleFallback(createdAt);
  }

  SessionListEntry copyWith({
    String? id,
    String? userId,
    String? title,
    bool clearTitle = false,
    String? status,
    String? rootAgentId,
    String? rootAgentName,
    String? rootAgentStatus,
    int? waitingForCount,
    String? lastMessagePreview,
    bool clearLastMessagePreview = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionListEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: clearTitle ? null : title ?? this.title,
      status: status ?? this.status,
      rootAgentId: rootAgentId ?? this.rootAgentId,
      rootAgentName: rootAgentName ?? this.rootAgentName,
      rootAgentStatus: rootAgentStatus ?? this.rootAgentStatus,
      waitingForCount: waitingForCount ?? this.waitingForCount,
      lastMessagePreview: clearLastMessagePreview
          ? null
          : lastMessagePreview ?? this.lastMessagePreview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
