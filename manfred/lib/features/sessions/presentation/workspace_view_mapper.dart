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
  final threadBuilders = <String, _ConversationThreadBuilder>{};
  final threadEntryIndexes = <String, int>{};
  String? lastDelegateThreadId;

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

        if (item.name == 'delegate') {
          final delegateCall = _parseDelegateCall(item.arguments);
          final threadId = _threadIdForCall(
            item.callId,
            fallbackSeed: entries.length,
          );
          final thread = threadBuilders.putIfAbsent(
            threadId,
            () => _ConversationThreadBuilder(
              id: threadId,
              agentName: delegateCall.agentName,
              task: delegateCall.task,
              createdAt: item.createdAt,
              placeholderLabel:
                  'Ten widok pokaże pełny transcript delegowanego agenta, gdy backend dopnie jednoznaczne grupowanie itemów.',
            ),
          );

          thread
            ..agentName = delegateCall.agentName
            ..task = delegateCall.task;
          entries.add(
            AgentPingConversationEntryMock(
              author: details.rootAgent.name,
              dateLabel: _formatDate(item.createdAt),
              timeLabel: _formatTime(item.createdAt),
              agentName: delegateCall.agentName,
              task: delegateCall.task,
            ),
          );
          threadEntryIndexes[threadId] = entries.length;
          entries.add(
            thread.toConversationEntry(
              dateLabel: _formatDate(item.createdAt),
              timeLabel: _formatTime(item.createdAt),
            ),
          );
          lastDelegateThreadId = threadId;
          continue;
        }

        if (item.name == 'ask_user') {
          final prompt = _extractAskUserPrompt(item.arguments);
          final dateLabel = _formatDate(item.createdAt);
          final timeLabel = _formatTime(item.createdAt);
          final thread = _resolveThreadForAskUser(
            threadBuilders: threadBuilders,
            preferredThreadId: lastDelegateThreadId,
            createdAt: item.createdAt,
          );

          if (thread != null) {
            thread
              ..markWaitingForUser()
              ..addEntry(
                UserPingConversationEntryMock(
                  author: thread.agentName,
                  dateLabel: dateLabel,
                  timeLabel: timeLabel,
                  userName: currentUserName,
                  task: prompt,
                ),
              );
          } else {
            entries.add(
              UserPingConversationEntryMock(
                author: details.rootAgent.name,
                dateLabel: dateLabel,
                timeLabel: timeLabel,
                userName: currentUserName,
                task: prompt,
              ),
            );
          }
          continue;
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

        if (item.name == 'ask_user') {
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

  _applyWaitingForToThreads(
    threadBuilders: threadBuilders,
    waitingFor: details.rootAgent.waitingFor,
    currentUserName: currentUserName,
    fallbackCreatedAt: details.session.updatedAt,
  );

  for (final entry in threadEntryIndexes.entries) {
    final thread = threadBuilders[entry.key];
    if (thread == null) {
      continue;
    }

    entries[entry.value] = thread.toConversationEntry(
      dateLabel: _formatDate(thread.createdAt),
      timeLabel: _formatTime(thread.createdAt),
    );
  }

  final knownThreadIds = threadEntryIndexes.keys.toSet();
  for (final thread in threadBuilders.values) {
    if (knownThreadIds.contains(thread.id)) {
      continue;
    }

    entries.add(
      thread.toConversationEntry(
        dateLabel: _formatDate(thread.createdAt),
        timeLabel: _formatTime(thread.createdAt),
      ),
    );
  }

  return SessionViewMock(
    title: details.session.displayTitle,
    rootAgent: details.rootAgent.name,
    entries: entries,
    threads: threadBuilders.values
        .map((thread) => thread.toThreadView())
        .toList(growable: false),
  );
}

SessionViewMock buildDraftSessionViewMock() {
  return const SessionViewMock(
    title: 'New session',
    rootAgent: 'Manfred',
    entries: <ConversationEntryMock>[],
    threads: <ConversationThreadMock>[],
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
  if (serialized.length <= 84) {
    return serialized;
  }

  return '${serialized.substring(0, 81)}...';
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

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item as Object?));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map(
          (key, item) => MapEntry(key.toString(), item as Object?),
        );
      }
    } on FormatException {
      return null;
    }
  }

  return null;
}

_DelegateCallData _parseDelegateCall(Object? arguments) {
  final map = _asObjectMap(arguments);
  final agentName = (map?['agent_name'] ?? map?['agentName'] ?? 'delegate')
      .toString()
      .trim();
  final task =
      (map?['task'] ?? map?['prompt'] ?? map?['description'] ?? arguments)
          .toString()
          .trim();

  return _DelegateCallData(
    agentName: agentName.isEmpty ? 'delegate' : agentName,
    task: task.isEmpty ? _compactJson(arguments) : task,
  );
}

String _extractAskUserPrompt(Object? arguments) {
  final map = _asObjectMap(arguments);
  final prompt =
      map?['description'] ??
      map?['question'] ??
      map?['prompt'] ??
      map?['message'] ??
      map?['request'] ??
      map?['task'] ??
      arguments;

  final text = prompt?.toString().trim() ?? '';
  if (text.isNotEmpty) {
    return text;
  }

  return _compactJson(arguments);
}

String _threadIdForCall(String callId, {required int fallbackSeed}) {
  final normalized = callId.trim();
  if (normalized.isNotEmpty) {
    return 'delegate:$normalized';
  }

  return 'delegate:auto-$fallbackSeed';
}

_ConversationThreadBuilder? _resolveThreadForAskUser({
  required Map<String, _ConversationThreadBuilder> threadBuilders,
  required String? preferredThreadId,
  required DateTime createdAt,
}) {
  if (preferredThreadId != null) {
    final thread = threadBuilders[preferredThreadId];
    if (thread != null) {
      return thread;
    }
  }

  if (threadBuilders.isEmpty) {
    return null;
  }

  final threads = threadBuilders.values.toList(growable: false)
    ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  return threads.last;
}

void _applyWaitingForToThreads({
  required Map<String, _ConversationThreadBuilder> threadBuilders,
  required List<Map<String, Object?>> waitingFor,
  required String currentUserName,
  required DateTime fallbackCreatedAt,
}) {
  for (final waiting in waitingFor) {
    if (waiting['type']?.toString() != 'agent' ||
        waiting['name']?.toString() != 'delegate') {
      continue;
    }

    final description = waiting['description']?.toString().trim() ?? '';
    final agentId = waiting['agent_id']?.toString().trim();
    final matchingThread = _matchWaitingThread(
      threadBuilders: threadBuilders,
      agentId: agentId,
      description: description,
    );
    final thread =
        matchingThread ??
        threadBuilders.putIfAbsent(
          agentId?.isNotEmpty == true
              ? 'delegate:$agentId'
              : 'delegate:waiting',
          () => _ConversationThreadBuilder(
            id: agentId?.isNotEmpty == true
                ? 'delegate:$agentId'
                : 'delegate:waiting',
            agentName: 'delegate',
            task: description.isEmpty ? 'Delegated task' : description,
            createdAt: fallbackCreatedAt,
            placeholderLabel:
                'Backend nie zwraca jeszcze pełnej mapy itemów subwątku, więc UI pokazuje bezpieczny fallback.',
          ),
        );

    thread.markWaitingForUser();
    if (description.isNotEmpty &&
        !thread.entries.any(
          (entry) =>
              entry is UserPingConversationEntryMock &&
              entry.task == description,
        )) {
      thread.addEntry(
        UserPingConversationEntryMock(
          author: thread.agentName,
          dateLabel: _formatDate(thread.createdAt),
          timeLabel: _formatTime(thread.createdAt),
          userName: currentUserName,
          task: description,
        ),
      );
    }
  }
}

_ConversationThreadBuilder? _matchWaitingThread({
  required Map<String, _ConversationThreadBuilder> threadBuilders,
  required String? agentId,
  required String description,
}) {
  if (agentId != null && agentId.isNotEmpty) {
    final direct = threadBuilders['delegate:$agentId'];
    if (direct != null) {
      return direct;
    }
  }

  for (final thread in threadBuilders.values) {
    if (description.isNotEmpty &&
        (thread.task.contains(description) ||
            description.contains(thread.task))) {
      return thread;
    }
  }

  if (threadBuilders.isEmpty) {
    return null;
  }

  return threadBuilders.values.last;
}

class _DelegateCallData {
  const _DelegateCallData({required this.agentName, required this.task});

  final String agentName;
  final String task;
}

class _ConversationThreadBuilder {
  _ConversationThreadBuilder({
    required this.id,
    required this.agentName,
    required this.task,
    required this.createdAt,
    required this.placeholderLabel,
  });

  final String id;
  String agentName;
  String task;
  DateTime createdAt;
  String? statusLabel;
  String placeholderLabel;
  final List<ConversationEntryMock> entries = <ConversationEntryMock>[];

  void addEntry(ConversationEntryMock entry) {
    entries.add(entry);
  }

  void markWaitingForUser() {
    statusLabel = 'Czeka na odpowiedź użytkownika.';
  }

  AgentThreadConversationEntryMock toConversationEntry({
    required String dateLabel,
    required String timeLabel,
  }) {
    return AgentThreadConversationEntryMock(
      author: agentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      threadId: id,
      agentName: agentName,
      taskPreview: task,
      threadTitle: '@$agentName',
      threadMeta: _threadMetaLabel(entries.length),
      statusLabel: statusLabel ?? 'W tym wątku nie ma nowych wiadomości.',
    );
  }

  ConversationThreadMock toThreadView() {
    return ConversationThreadMock(
      id: id,
      agentName: agentName,
      title: '@$agentName',
      task: task,
      statusLabel: statusLabel ?? 'W tym wątku nie ma nowych wiadomości.',
      metaLabel: _threadMetaLabel(entries.length),
      placeholderLabel: placeholderLabel,
      entries: List<ConversationEntryMock>.unmodifiable(entries),
    );
  }
}

String _threadMetaLabel(int count) {
  if (count == 1) {
    return '1 wpis';
  }
  if (count >= 2 && count <= 4) {
    return '$count wpisy';
  }

  return '$count wpisów';
}
