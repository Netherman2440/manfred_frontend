import 'session_title_formatter.dart';
import 'session_item.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return formatSessionTitleFallback(createdAt);
  }

  SessionSummary copyWith({
    String? id,
    String? userId,
    String? title,
    bool clearTitle = false,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionSummary(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: clearTitle ? null : title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RootAgentSummary {
  const RootAgentSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.model,
    required this.waitingFor,
  });

  final String id;
  final String name;
  final String status;
  final String model;
  final List<Map<String, Object?>> waitingFor;

  RootAgentSummary copyWith({
    String? id,
    String? name,
    String? status,
    String? model,
    List<Map<String, Object?>>? waitingFor,
  }) {
    return RootAgentSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      model: model ?? this.model,
      waitingFor: waitingFor ?? this.waitingFor,
    );
  }
}

class SessionDetails {
  const SessionDetails({
    required this.session,
    required this.rootAgent,
    required this.items,
    this.isWaitingForTextResponse = false,
    this.streamingMessageItemId,
  });

  final SessionSummary session;
  final RootAgentSummary rootAgent;
  final List<SessionItem> items;
  final bool isWaitingForTextResponse;
  final String? streamingMessageItemId;

  SessionDetails copyWith({
    SessionSummary? session,
    RootAgentSummary? rootAgent,
    List<SessionItem>? items,
    bool? isWaitingForTextResponse,
    String? streamingMessageItemId,
    bool clearStreamingMessageItemId = false,
  }) {
    return SessionDetails(
      session: session ?? this.session,
      rootAgent: rootAgent ?? this.rootAgent,
      items: items ?? this.items,
      isWaitingForTextResponse:
          isWaitingForTextResponse ?? this.isWaitingForTextResponse,
      streamingMessageItemId: clearStreamingMessageItemId
          ? null
          : streamingMessageItemId ?? this.streamingMessageItemId,
    );
  }
}
