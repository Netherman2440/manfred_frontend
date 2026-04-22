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
  final rootItems = <SessionItem>[];
  final nonRootItemsByAgent = <String, List<SessionItem>>{};

  for (final item in details.items) {
    if (item.agentId == details.rootAgent.id) {
      rootItems.add(item);
      continue;
    }

    nonRootItemsByAgent
        .putIfAbsent(item.agentId, () => <SessionItem>[])
        .add(item);
  }

  final pendingDelegates = <_PendingDelegateCall>[];
  final rootTimeline = _buildRootTimelineEntries(
    items: _sortAgentItems(rootItems),
    rootAgentName: details.rootAgent.name,
    currentUserName: currentUserName,
    pendingDelegates: pendingDelegates,
  );

  final threadBuilders = <String, _ConversationThreadBuilder>{};
  for (final entry in nonRootItemsByAgent.entries) {
    final items = _sortAgentItems(entry.value);
    if (items.isEmpty) {
      continue;
    }

    final thread = _ConversationThreadBuilder(
      agentId: entry.key,
      id: _threadIdForAgent(entry.key),
      agentName: _fallbackAgentName(entry.key),
      task: _deriveThreadTask(items),
      createdAt: items.first.createdAt,
      firstSequence: items.first.sequence,
      placeholderLabel:
          'Ten widok pokazuje wszystkie itemy przypisane do subagenta na podstawie agent_id.',
    );

    _matchThreadWithDelegate(
      thread: thread,
      pendingDelegates: pendingDelegates,
    );
    _populateThreadEntries(
      thread: thread,
      items: items,
      rootAgentName: details.rootAgent.name,
      currentUserName: currentUserName,
    );
    threadBuilders[thread.agentId] = thread;
  }

  _applyWaitingForToThreads(
    threadBuilders: threadBuilders,
    waitingFor: details.rootAgent.waitingFor,
    currentUserName: currentUserName,
    fallbackCreatedAt: details.session.updatedAt,
    rootAgentName: details.rootAgent.name,
    pendingDelegates: pendingDelegates,
  );

  final timeline = <_TimelineEntry>[
    ...rootTimeline,
    ...threadBuilders.values.map(
      (thread) => _TimelineEntry(
        createdAt: thread.createdAt,
        sequence: thread.firstSequence,
        entry: thread.toConversationEntry(),
      ),
    ),
  ]..sort(_compareTimelineEntries);

  final threads = threadBuilders.values.toList()
    ..sort((left, right) => _compareAgentItems(left, right));

  return SessionViewMock(
    title: details.session.displayTitle,
    rootAgent: details.rootAgent.name,
    entries: timeline.map((item) => item.entry).toList(growable: false),
    threads: threads
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

List<_TimelineEntry> _buildRootTimelineEntries({
  required List<SessionItem> items,
  required String rootAgentName,
  required String currentUserName,
  required List<_PendingDelegateCall> pendingDelegates,
}) {
  final entries = <_TimelineEntry>[];
  final consumedResultIds = <String>{};

  for (var index = 0; index < items.length; index += 1) {
    final item = items[index];
    if (consumedResultIds.contains(item.id)) {
      continue;
    }

    final linkedResult = _linkedResult(items, index);
    if (linkedResult != null) {
      consumedResultIds.add(linkedResult.id);
    }

    final entry = switch (item) {
      SessionMessageItem() => _mapRootMessage(
        item: item,
        rootAgentName: rootAgentName,
        currentUserName: currentUserName,
      ),
      SessionToolCallItem() => _mapRootToolCall(
        item: item,
        linkedResult: linkedResult,
        rootAgentName: rootAgentName,
        currentUserName: currentUserName,
        pendingDelegates: pendingDelegates,
      ),
      SessionToolResultItem() => _mapRootToolResult(
        item: item,
        rootAgentName: rootAgentName,
      ),
      SessionReasoningItem() => null,
    };

    if (entry == null) {
      continue;
    }

    entries.add(
      _TimelineEntry(
        createdAt: item.createdAt,
        sequence: item.sequence,
        entry: entry,
      ),
    );
  }

  return entries;
}

ConversationEntryMock? _mapRootMessage({
  required SessionMessageItem item,
  required String rootAgentName,
  required String currentUserName,
}) {
  final dateLabel = _formatDate(item.createdAt);
  final timeLabel = _formatTime(item.createdAt);

  if (item.role == 'user') {
    return UserConversationEntryMock(
      author: currentUserName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      body: item.content,
    );
  }

  return AgentConversationEntryMock(
    author: rootAgentName,
    dateLabel: dateLabel,
    timeLabel: timeLabel,
    body: item.content,
  );
}

ConversationEntryMock? _mapRootToolCall({
  required SessionToolCallItem item,
  required SessionToolResultItem? linkedResult,
  required String rootAgentName,
  required String currentUserName,
  required List<_PendingDelegateCall> pendingDelegates,
}) {
  final dateLabel = _formatDate(item.createdAt);
  final timeLabel = _formatTime(item.createdAt);

  if (item.name == 'delegate') {
    final delegateCall = _parseDelegateCall(item.arguments);
    pendingDelegates.add(
      _PendingDelegateCall(
        agentName: delegateCall.agentName,
        task: delegateCall.task,
        createdAt: item.createdAt,
      ),
    );
    return AgentPingConversationEntryMock(
      author: rootAgentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      agentName: delegateCall.agentName,
      task: delegateCall.task,
    );
  }

  if (item.name == 'ask_user') {
    return UserPingConversationEntryMock(
      author: rootAgentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      userName: currentUserName,
      task: _extractAskUserPrompt(item.arguments),
    );
  }

  return ToolCallConversationEntryMock(
    author: rootAgentName,
    dateLabel: dateLabel,
    timeLabel: timeLabel,
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
  );
}

ConversationEntryMock? _mapRootToolResult({
  required SessionToolResultItem item,
  required String rootAgentName,
}) {
  if (item.name == 'ask_user') {
    return null;
  }

  return ToolCallConversationEntryMock(
    author: rootAgentName,
    dateLabel: _formatDate(item.createdAt),
    timeLabel: _formatTime(item.createdAt),
    toolName: item.name,
    argumentsPreview: '{}',
    argumentsJson: '{}',
    outputPreview: _compactJson(item.toolResult),
    outputJson: _prettyJson(item.toolResult),
  );
}

void _populateThreadEntries({
  required _ConversationThreadBuilder thread,
  required List<SessionItem> items,
  required String rootAgentName,
  required String currentUserName,
}) {
  final consumedResultIds = <String>{};

  for (var index = 0; index < items.length; index += 1) {
    final item = items[index];
    if (consumedResultIds.contains(item.id)) {
      continue;
    }

    final linkedResult = _linkedResult(items, index);
    if (linkedResult != null) {
      consumedResultIds.add(linkedResult.id);
    }

    final entry = switch (item) {
      SessionMessageItem() => _mapThreadMessage(
        item: item,
        thread: thread,
        rootAgentName: rootAgentName,
      ),
      SessionToolCallItem() => _mapThreadToolCall(
        item: item,
        linkedResult: linkedResult,
        thread: thread,
        currentUserName: currentUserName,
      ),
      SessionToolResultItem() => _mapThreadToolResult(
        item: item,
        thread: thread,
      ),
      SessionReasoningItem() => null,
    };

    if (entry == null) {
      continue;
    }

    thread.addEntry(entry);
  }
}

ConversationEntryMock _mapThreadMessage({
  required SessionMessageItem item,
  required _ConversationThreadBuilder thread,
  required String rootAgentName,
}) {
  final author = item.role == 'user' ? rootAgentName : thread.agentName;
  return AgentConversationEntryMock(
    author: author,
    dateLabel: _formatDate(item.createdAt),
    timeLabel: _formatTime(item.createdAt),
    body: item.content,
  );
}

ConversationEntryMock? _mapThreadToolCall({
  required SessionToolCallItem item,
  required SessionToolResultItem? linkedResult,
  required _ConversationThreadBuilder thread,
  required String currentUserName,
}) {
  final dateLabel = _formatDate(item.createdAt);
  final timeLabel = _formatTime(item.createdAt);

  if (item.name == 'delegate') {
    final delegateCall = _parseDelegateCall(item.arguments);
    return AgentPingConversationEntryMock(
      author: thread.agentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      agentName: delegateCall.agentName,
      task: delegateCall.task,
    );
  }

  if (item.name == 'ask_user') {
    thread.markWaitingForUser();
    return UserPingConversationEntryMock(
      author: thread.agentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      userName: currentUserName,
      task: _extractAskUserPrompt(item.arguments),
    );
  }

  return ToolCallConversationEntryMock(
    author: thread.agentName,
    dateLabel: dateLabel,
    timeLabel: timeLabel,
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
  );
}

ConversationEntryMock? _mapThreadToolResult({
  required SessionToolResultItem item,
  required _ConversationThreadBuilder thread,
}) {
  if (item.name == 'ask_user') {
    return null;
  }

  return ToolCallConversationEntryMock(
    author: thread.agentName,
    dateLabel: _formatDate(item.createdAt),
    timeLabel: _formatTime(item.createdAt),
    toolName: item.name,
    argumentsPreview: '{}',
    argumentsJson: '{}',
    outputPreview: _compactJson(item.toolResult),
    outputJson: _prettyJson(item.toolResult),
  );
}

void _matchThreadWithDelegate({
  required _ConversationThreadBuilder thread,
  required List<_PendingDelegateCall> pendingDelegates,
}) {
  _PendingDelegateCall? matched;

  for (final delegate in pendingDelegates) {
    if (delegate.isMatched) {
      continue;
    }
    if (delegate.task == thread.task) {
      matched = delegate;
      break;
    }
  }

  matched ??= pendingDelegates
      .where((delegate) => !delegate.isMatched)
      .fold<_PendingDelegateCall?>(null, (current, candidate) {
        if (candidate.createdAt.isAfter(thread.createdAt)) {
          return current;
        }
        if (current == null) {
          return candidate;
        }
        return candidate.createdAt.isAfter(current.createdAt)
            ? candidate
            : current;
      });

  if (matched == null) {
    return;
  }

  matched.isMatched = true;
  thread
    ..agentName = matched.agentName
    ..task = matched.task;
}

void _applyWaitingForToThreads({
  required Map<String, _ConversationThreadBuilder> threadBuilders,
  required List<Map<String, Object?>> waitingFor,
  required String currentUserName,
  required DateTime fallbackCreatedAt,
  required String rootAgentName,
  required List<_PendingDelegateCall> pendingDelegates,
}) {
  for (final waiting in waitingFor) {
    if (waiting['type']?.toString() != 'agent' ||
        waiting['name']?.toString() != 'delegate') {
      continue;
    }

    final agentId = waiting['agent_id']?.toString().trim() ?? '';
    final description = waiting['description']?.toString().trim() ?? '';
    final thread = threadBuilders.putIfAbsent(agentId, () {
      final builder = _ConversationThreadBuilder(
        agentId: agentId,
        id: _threadIdForAgent(agentId),
        agentName: _fallbackAgentName(agentId),
        task: description.isEmpty ? 'Delegated task' : description,
        createdAt: fallbackCreatedAt,
        firstSequence: 1 << 30,
        placeholderLabel:
            'Backend nie zwraca jeszcze żadnych itemów tego subagenta, więc UI pokazuje fallback oparty o waiting_for.',
      );
      _matchThreadWithDelegate(
        thread: builder,
        pendingDelegates: pendingDelegates,
      );
      return builder;
    });

    thread.markWaitingForUser();
    if (description.isEmpty) {
      continue;
    }

    final alreadyExists = thread.entries.any(
      (entry) =>
          entry is UserPingConversationEntryMock && entry.task == description,
    );
    if (alreadyExists) {
      continue;
    }

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

SessionToolResultItem? _linkedResult(List<SessionItem> items, int index) {
  if (index + 1 >= items.length) {
    return null;
  }

  final current = items[index];
  final next = items[index + 1];
  if (current is! SessionToolCallItem || next is! SessionToolResultItem) {
    return null;
  }
  if (current.callId != next.callId) {
    return null;
  }

  return next;
}

List<SessionItem> _sortAgentItems(List<SessionItem> items) {
  final sorted = List<SessionItem>.from(items);
  sorted.sort(_compareSessionItems);
  return sorted;
}

int _compareSessionItems(SessionItem left, SessionItem right) {
  final bySequence = left.sequence.compareTo(right.sequence);
  if (bySequence != 0) {
    return bySequence;
  }

  final byTime = left.createdAt.compareTo(right.createdAt);
  if (byTime != 0) {
    return byTime;
  }

  return left.id.compareTo(right.id);
}

int _compareAgentItems(
  _ConversationThreadBuilder left,
  _ConversationThreadBuilder right,
) {
  final byTime = left.createdAt.compareTo(right.createdAt);
  if (byTime != 0) {
    return byTime;
  }

  return left.agentId.compareTo(right.agentId);
}

int _compareTimelineEntries(_TimelineEntry left, _TimelineEntry right) {
  final byTime = left.createdAt.compareTo(right.createdAt);
  if (byTime != 0) {
    return byTime;
  }

  return left.sequence.compareTo(right.sequence);
}

String _deriveThreadTask(List<SessionItem> items) {
  for (final item in items) {
    if (item is SessionMessageItem &&
        item.role == 'user' &&
        item.content.trim().isNotEmpty) {
      return item.content.trim();
    }
    if (item is SessionToolCallItem && item.name == 'delegate') {
      return _parseDelegateCall(item.arguments).task;
    }
  }

  for (final item in items) {
    if (item is SessionToolCallItem && item.name == 'ask_user') {
      return _extractAskUserPrompt(item.arguments);
    }
  }

  return 'Delegated task';
}

String _threadIdForAgent(String agentId) {
  if (agentId.trim().isEmpty) {
    return 'agent:unknown';
  }

  return 'agent:$agentId';
}

String _fallbackAgentName(String agentId) {
  final normalized = agentId.trim();
  if (normalized.isEmpty) {
    return 'agent';
  }
  if (normalized.length <= 8) {
    return normalized;
  }

  return 'agent:${normalized.substring(0, 6)}';
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

class _TimelineEntry {
  const _TimelineEntry({
    required this.createdAt,
    required this.sequence,
    required this.entry,
  });

  final DateTime createdAt;
  final int sequence;
  final ConversationEntryMock entry;
}

class _PendingDelegateCall {
  _PendingDelegateCall({
    required this.agentName,
    required this.task,
    required this.createdAt,
  });

  final String agentName;
  final String task;
  final DateTime createdAt;
  bool isMatched = false;
}

class _DelegateCallData {
  const _DelegateCallData({required this.agentName, required this.task});

  final String agentName;
  final String task;
}

class _ConversationThreadBuilder {
  _ConversationThreadBuilder({
    required this.agentId,
    required this.id,
    required this.agentName,
    required this.task,
    required this.createdAt,
    required this.firstSequence,
    required this.placeholderLabel,
  });

  final String agentId;
  final String id;
  String agentName;
  String task;
  DateTime createdAt;
  int firstSequence;
  String? statusLabel;
  String placeholderLabel;
  final List<ConversationEntryMock> entries = <ConversationEntryMock>[];

  void addEntry(ConversationEntryMock entry) {
    entries.add(entry);
  }

  void markWaitingForUser() {
    statusLabel = 'Czeka na odpowiedź użytkownika.';
  }

  AgentThreadConversationEntryMock toConversationEntry() {
    return AgentThreadConversationEntryMock(
      author: agentName,
      dateLabel: _formatDate(createdAt),
      timeLabel: _formatTime(createdAt),
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
