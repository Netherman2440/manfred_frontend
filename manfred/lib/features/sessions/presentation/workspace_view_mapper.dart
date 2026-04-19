import 'dart:convert';

import '../../../ui/mock/manfred_mock_data.dart';
import '../domain/session_details.dart';
import '../domain/session_item.dart';
import '../domain/session_list_entry.dart';

List<SessionMock> buildSessionMocks(
  List<SessionListEntry> sessions, {
  required String? activeSessionId,
  required bool isDraft,
}) {
  return sessions
      .map(
        (session) => SessionMock(
          id: session.id,
          prefix: '#',
          title: session.displayTitle,
          isActive: !isDraft && session.id == activeSessionId,
        ),
      )
      .toList(growable: false);
}

SessionViewMock buildSessionViewMock(
  SessionDetails details, {
  required String currentUserName,
}) {
  final entries = <ConversationEntryMock>[];
  final consumedResultIds = <String>{};

  for (var index = 0; index < details.items.length; index += 1) {
    final item = details.items[index];

    switch (item) {
      case SessionMessageItem():
        final dateLabel = _formatDate(item.createdAt);
        final timeLabel = _formatTime(item.createdAt);
        if (item.role == 'user') {
          entries.add(
            UserConversationEntryMock(
              author: currentUserName,
              dateLabel: dateLabel,
              timeLabel: timeLabel,
              body: item.content,
            ),
          );
        } else {
          entries.add(
            AgentConversationEntryMock(
              author: details.rootAgent.name,
              dateLabel: dateLabel,
              timeLabel: timeLabel,
              body: item.content,
            ),
          );
        }
      case SessionToolCallItem():
        final nextItem = index + 1 < details.items.length
            ? details.items[index + 1]
            : null;
        final linkedResult =
            nextItem is SessionToolResultItem && nextItem.callId == item.callId
            ? nextItem
            : null;
        if (linkedResult != null) {
          consumedResultIds.add(linkedResult.id);
        }

        entries.add(
          ToolCallConversationEntryMock(
            author: details.rootAgent.name,
            dateLabel: _formatDate(item.createdAt),
            timeLabel: _formatTime(item.createdAt),
            toolName: item.name,
            argumentsPreview: _compactJson(item.arguments),
            argumentsJson: _prettyJson(item.arguments),
            outputPreview: linkedResult == null
                ? null
                : _compactJson(linkedResult.toolResult),
            outputJson: linkedResult == null
                ? null
                : _prettyJson(linkedResult.toolResult),
            isOutputPending: linkedResult == null,
          ),
        );
      case SessionToolResultItem():
        if (consumedResultIds.contains(item.id)) {
          continue;
        }

        entries.add(
          ToolCallConversationEntryMock(
            author: details.rootAgent.name,
            dateLabel: _formatDate(item.createdAt),
            timeLabel: _formatTime(item.createdAt),
            toolName: item.name,
            argumentsPreview: '{}',
            argumentsJson: '{}',
            outputPreview: _compactJson(item.toolResult),
            outputJson: _prettyJson(item.toolResult),
          ),
        );
      case SessionReasoningItem():
        continue;
    }
  }

  return SessionViewMock(
    title: details.session.displayTitle,
    rootAgent: details.rootAgent.name,
    entries: entries,
  );
}

SessionViewMock buildDraftSessionViewMock() {
  return const SessionViewMock(
    title: 'New session',
    rootAgent: 'Manfred',
    entries: <ConversationEntryMock>[],
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  return '$day.$month.$year';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _compactJson(Object? value) {
  final serialized = _serialize(value);
  if (serialized.length <= 100) {
    return serialized;
  }

  return '${serialized.substring(0, 97)}...';
}

String _prettyJson(Object? value) {
  if (value == null) {
    return '{}';
  }
  if (value is String) {
    return value;
  }
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _serialize(Object? value) {
  if (value == null) {
    return '{}';
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}
