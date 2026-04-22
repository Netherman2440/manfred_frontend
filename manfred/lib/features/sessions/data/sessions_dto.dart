import '../domain/session_details.dart';
import '../domain/session_item.dart';
import '../domain/session_list_entry.dart';

class SessionsListResponseDto {
  const SessionsListResponseDto({required this.data});

  final List<SessionListEntryDto> data;

  factory SessionsListResponseDto.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = rawData is List<Object?> ? rawData : const <Object?>[];

    return SessionsListResponseDto(
      data: items
          .whereType<Map<String, dynamic>>()
          .map(SessionListEntryDto.fromJson)
          .toList(growable: false),
    );
  }
}

class SessionListEntryDto {
  const SessionListEntryDto({
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

  factory SessionListEntryDto.fromJson(Map<String, dynamic> json) {
    return SessionListEntryDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'unknown',
      rootAgentId: json['root_agent_id'] as String? ?? '',
      rootAgentName: json['root_agent_name'] as String? ?? 'Manfred',
      rootAgentStatus: json['root_agent_status'] as String? ?? 'unknown',
      waitingForCount: _readInt(json['waiting_for_count']),
      lastMessagePreview: json['last_message_preview'] as String?,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  SessionListEntry toDomain() {
    return SessionListEntry(
      id: id,
      userId: userId,
      title: title,
      status: status,
      rootAgentId: rootAgentId,
      rootAgentName: rootAgentName,
      rootAgentStatus: rootAgentStatus,
      waitingForCount: waitingForCount,
      lastMessagePreview: lastMessagePreview,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class SessionDetailsResponseDto {
  const SessionDetailsResponseDto({required this.data});

  final SessionDetailsDto data;

  factory SessionDetailsResponseDto.fromJson(Map<String, dynamic> json) {
    return SessionDetailsResponseDto(
      data: SessionDetailsDto.fromJson(
        json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class SessionDetailsDto {
  const SessionDetailsDto({
    required this.session,
    required this.rootAgent,
    required this.items,
  });

  final SessionSummaryDto session;
  final RootAgentSummaryDto rootAgent;
  final List<SessionItemDto> items;

  factory SessionDetailsDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List<Object?> ? rawItems : const <Object?>[];

    return SessionDetailsDto(
      session: SessionSummaryDto.fromJson(
        json['session'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      rootAgent: RootAgentSummaryDto.fromJson(
        json['root_agent'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(SessionItemDto.fromJson)
          .toList(growable: false),
    );
  }

  SessionDetails toDomain() {
    return SessionDetails(
      session: session.toDomain(),
      rootAgent: rootAgent.toDomain(),
      items: items.map((item) => item.toDomain()).toList(growable: false),
    );
  }
}

class SessionSummaryDto {
  const SessionSummaryDto({
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

  factory SessionSummaryDto.fromJson(Map<String, dynamic> json) {
    return SessionSummaryDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'unknown',
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  SessionSummary toDomain() {
    return SessionSummary(
      id: id,
      userId: userId,
      title: title,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class RootAgentSummaryDto {
  const RootAgentSummaryDto({
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

  factory RootAgentSummaryDto.fromJson(Map<String, dynamic> json) {
    final rawWaitingFor = json['waiting_for'];
    final waitingFor = rawWaitingFor is List<Object?>
        ? rawWaitingFor
        : const <Object?>[];

    return RootAgentSummaryDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Manfred',
      status: json['status'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'unknown',
      waitingFor: waitingFor
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => item.map((key, value) => MapEntry(key, value as Object?)),
          )
          .toList(growable: false),
    );
  }

  RootAgentSummary toDomain() {
    return RootAgentSummary(
      id: id,
      name: name,
      status: status,
      model: model,
      waitingFor: waitingFor,
    );
  }
}

class SessionItemDto {
  const SessionItemDto({
    required this.id,
    required this.type,
    required this.agentId,
    required this.sequence,
    required this.createdAt,
    this.role,
    this.content,
    this.callId,
    this.name,
    this.arguments,
    this.toolResult,
    this.isError,
  });

  final String id;
  final String type;
  final String agentId;
  final int sequence;
  final DateTime createdAt;
  final String? role;
  final String? content;
  final String? callId;
  final String? name;
  final Object? arguments;
  final Object? toolResult;
  final bool? isError;

  factory SessionItemDto.fromJson(Map<String, dynamic> json) {
    return SessionItemDto(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      agentId: json['agent_id'] as String? ?? '',
      sequence: _readInt(json['sequence']),
      createdAt: _readDateTime(json['created_at']),
      role: json['role'] as String?,
      content: json['content'] as String?,
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'],
      toolResult: json['tool_result'],
      isError: json['is_error'] as bool?,
    );
  }

  SessionItem toDomain() {
    switch (type) {
      case 'function_call':
        return SessionToolCallItem(
          id: id,
          agentId: agentId,
          sequence: sequence,
          createdAt: createdAt,
          callId: callId ?? '',
          name: name ?? 'tool',
          arguments: arguments,
        );
      case 'function_call_output':
        return SessionToolResultItem(
          id: id,
          agentId: agentId,
          sequence: sequence,
          createdAt: createdAt,
          callId: callId ?? '',
          name: name ?? 'tool',
          toolResult: toolResult,
          isError: isError ?? false,
        );
      case 'reasoning':
        return SessionReasoningItem(
          id: id,
          agentId: agentId,
          sequence: sequence,
          createdAt: createdAt,
          content: content,
        );
      case 'message':
      default:
        return SessionMessageItem(
          id: id,
          agentId: agentId,
          sequence: sequence,
          createdAt: createdAt,
          role: role ?? 'assistant',
          content: content ?? '',
        );
    }
  }
}

DateTime _readDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return 0;
}
