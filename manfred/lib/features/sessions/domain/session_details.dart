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

    return 'Untitled session';
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
}

class SessionDetails {
  const SessionDetails({
    required this.session,
    required this.rootAgent,
    required this.items,
  });

  final SessionSummary session;
  final RootAgentSummary rootAgent;
  final List<SessionItem> items;
}
