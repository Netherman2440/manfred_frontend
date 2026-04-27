import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session_details.dart';
import '../domain/session_item.dart';
import '../domain/session_list_entry.dart';
import 'selected_session_provider.dart';
import 'session_details_provider.dart';
import 'sessions_list_provider.dart';

final sessionsListViewProvider = Provider<AsyncValue<List<SessionListEntry>>>((
  ref,
) {
  final overlay = ref.watch(sessionsListOverlayProvider);
  final baseAsync = ref.watch(sessionsListProvider);
  if (overlay.isEmpty) {
    return baseAsync;
  }

  final baseSessions = baseAsync.valueOrNull ?? const <SessionListEntry>[];
  return AsyncValue.data(_mergeSessionLists(baseSessions, overlay));
});

final activeSessionDetailsViewProvider = Provider<AsyncValue<SessionDetails?>>((
  ref,
) {
  final selection = ref.watch(selectedSessionProvider);
  final sessionId = selection.sessionId;
  if (sessionId == null) {
    return const AsyncValue.data(null);
  }

  final overlay = ref.watch(
    sessionDetailsOverlayProvider.select((value) => value[sessionId]),
  );
  if (overlay != null) {
    return AsyncValue.data(overlay);
  }

  return ref.watch(sessionDetailsProvider);
});

class SessionsListOverlayController extends Notifier<List<SessionListEntry>> {
  @override
  List<SessionListEntry> build() => const <SessionListEntry>[];

  void syncStreamStart({
    required String sessionId,
    required String userId,
    required String message,
    required String rootAgentId,
    required String rootAgentName,
    required DateTime startedAt,
  }) {
    final existing = _findSession(sessionId);
    upsert(
      (existing ??
              SessionListEntry(
                id: sessionId,
                userId: userId,
                title: null,
                status: 'active',
                rootAgentId: rootAgentId,
                rootAgentName: rootAgentName,
                rootAgentStatus: 'running',
                waitingForCount: 0,
                lastMessagePreview: message,
                createdAt: startedAt,
                updatedAt: startedAt,
              ))
          .copyWith(
            userId: userId,
            status: 'active',
            rootAgentId: rootAgentId,
            rootAgentName: rootAgentName,
            rootAgentStatus: 'running',
            waitingForCount: 0,
            lastMessagePreview: message,
            createdAt: existing?.createdAt ?? startedAt,
            updatedAt: startedAt,
          ),
    );
  }

  void syncStreamDone({
    required String sessionId,
    required DateTime finishedAt,
    required String? finalPreview,
    String rootAgentStatus = 'completed',
  }) {
    final existing = _findSession(sessionId);
    if (existing == null) {
      return;
    }

    upsert(
      existing.copyWith(
        rootAgentStatus: rootAgentStatus,
        lastMessagePreview: finalPreview,
        updatedAt: finishedAt,
      ),
    );
  }

  void upsert(SessionListEntry entry) {
    state = <SessionListEntry>[
      entry,
      for (final session in state)
        if (session.id != entry.id) session,
    ];
  }

  void remove(String sessionId) {
    state = state
        .where((session) => session.id != sessionId)
        .toList(growable: false);
  }

  void clear() {
    state = const <SessionListEntry>[];
  }

  SessionListEntry? _findSession(String sessionId) {
    for (final session in state) {
      if (session.id == sessionId) {
        return session;
      }
    }

    final baseSessions = ref.read(sessionsListProvider).valueOrNull;
    if (baseSessions == null) {
      return null;
    }

    for (final session in baseSessions) {
      if (session.id == sessionId) {
        return session;
      }
    }

    return null;
  }
}

class SessionDetailsOverlayController
    extends Notifier<Map<String, SessionDetails>> {
  @override
  Map<String, SessionDetails> build() => const <String, SessionDetails>{};

  void syncStreamStart({
    required String sessionId,
    required String userId,
    required String message,
    required String rootAgentId,
    required String rootAgentName,
    required DateTime startedAt,
  }) {
    final current = _resolveDetails(
      sessionId: sessionId,
      userId: userId,
      rootAgentId: rootAgentId,
      rootAgentName: rootAgentName,
      fallbackTime: startedAt,
    );
    final nextSequence = _nextSequence(current.items);
    final items = <SessionItem>[
      ...current.items,
      SessionMessageItem(
        id: 'local-user-$sessionId-$nextSequence',
        agentId: rootAgentId,
        sequence: nextSequence,
        createdAt: startedAt,
        role: 'user',
        content: message,
      ),
    ];

    replace(
      current.copyWith(
        session: current.session.copyWith(
          id: sessionId,
          userId: userId,
          status: 'active',
          createdAt: current.session.createdAt,
          updatedAt: startedAt,
        ),
        rootAgent: current.rootAgent.copyWith(
          id: rootAgentId,
          name: rootAgentName,
          status: 'running',
        ),
        items: items,
        isWaitingForTextResponse: true,
        clearStreamingMessageItemId: true,
      ),
    );
  }

  void appendStreamingText({
    required String sessionId,
    required String delta,
    required DateTime updatedAt,
  }) {
    final current = state[sessionId];
    if (current == null) {
      return;
    }

    final items = List<SessionItem>.from(current.items);
    final assistantIndex = _findStreamingAssistantIndex(
      items,
      current.streamingMessageItemId,
    );
    var streamingMessageItemId = current.streamingMessageItemId;
    if (assistantIndex == null) {
      final nextSequence = _nextSequence(items);
      final messageId = 'local-assistant-$sessionId-$nextSequence';
      items.add(
        SessionMessageItem(
          id: messageId,
          agentId: current.rootAgent.id,
          sequence: nextSequence,
          createdAt: updatedAt,
          role: 'assistant',
          content: delta,
        ),
      );
      streamingMessageItemId = messageId;
    } else {
      final assistantItem = items[assistantIndex] as SessionMessageItem;
      items[assistantIndex] = SessionMessageItem(
        id: assistantItem.id,
        agentId: assistantItem.agentId,
        sequence: assistantItem.sequence,
        createdAt: assistantItem.createdAt,
        role: assistantItem.role,
        content: '${assistantItem.content}$delta',
      );
      streamingMessageItemId = assistantItem.id;
    }

    replace(
      current.copyWith(
        session: current.session.copyWith(updatedAt: updatedAt),
        rootAgent: current.rootAgent.copyWith(status: 'running'),
        items: items,
        isWaitingForTextResponse: false,
        streamingMessageItemId: streamingMessageItemId,
      ),
    );
  }

  void setStreamingText({
    required String sessionId,
    required String text,
    required DateTime updatedAt,
  }) {
    final current = state[sessionId];
    if (current == null) {
      return;
    }

    final items = List<SessionItem>.from(current.items);
    final assistantIndex = _findStreamingAssistantIndex(
      items,
      current.streamingMessageItemId,
    );
    var streamingMessageItemId = current.streamingMessageItemId;
    if (assistantIndex == null) {
      final nextSequence = _nextSequence(items);
      final messageId = 'local-assistant-$sessionId-$nextSequence';
      items.add(
        SessionMessageItem(
          id: messageId,
          agentId: current.rootAgent.id,
          sequence: nextSequence,
          createdAt: updatedAt,
          role: 'assistant',
          content: text,
        ),
      );
      streamingMessageItemId = messageId;
    } else {
      final assistantItem = items[assistantIndex] as SessionMessageItem;
      items[assistantIndex] = SessionMessageItem(
        id: assistantItem.id,
        agentId: assistantItem.agentId,
        sequence: assistantItem.sequence,
        createdAt: assistantItem.createdAt,
        role: assistantItem.role,
        content: text,
      );
      streamingMessageItemId = assistantItem.id;
    }

    replace(
      current.copyWith(
        session: current.session.copyWith(updatedAt: updatedAt),
        rootAgent: current.rootAgent.copyWith(status: 'running'),
        items: items,
        isWaitingForTextResponse: false,
        streamingMessageItemId: streamingMessageItemId,
      ),
    );
  }

  void upsertToolCall({
    required String sessionId,
    required String callId,
    required String name,
    required Object? arguments,
    required DateTime updatedAt,
  }) {
    final current = state[sessionId];
    if (current == null) {
      return;
    }

    final items = List<SessionItem>.from(current.items);
    final existingIndex = _findToolCallIndex(items, callId);
    if (existingIndex == null) {
      final nextSequence = _nextSequence(items);
      items.add(
        SessionToolCallItem(
          id: 'local-tool-$sessionId-$callId',
          agentId: current.rootAgent.id,
          sequence: nextSequence,
          createdAt: updatedAt,
          callId: callId,
          name: name,
          arguments: arguments,
        ),
      );
    } else {
      final existingItem = items[existingIndex] as SessionToolCallItem;
      items[existingIndex] = SessionToolCallItem(
        id: existingItem.id,
        agentId: existingItem.agentId,
        sequence: existingItem.sequence,
        createdAt: existingItem.createdAt,
        callId: existingItem.callId,
        name: name,
        arguments: arguments,
      );
    }

    replace(
      current.copyWith(
        session: current.session.copyWith(updatedAt: updatedAt),
        rootAgent: current.rootAgent.copyWith(status: 'running'),
        items: items,
      ),
    );
  }

  void syncStreamDone({
    required String sessionId,
    required DateTime finishedAt,
    String rootAgentStatus = 'completed',
  }) {
    final current = state[sessionId];
    if (current == null) {
      return;
    }

    replace(
      current.copyWith(
        session: current.session.copyWith(updatedAt: finishedAt),
        rootAgent: current.rootAgent.copyWith(status: rootAgentStatus),
        isWaitingForTextResponse: false,
        clearStreamingMessageItemId: true,
      ),
    );
  }

  void replace(SessionDetails details) {
    state = <String, SessionDetails>{...state, details.session.id: details};
  }

  void remove(String sessionId) {
    if (!state.containsKey(sessionId)) {
      return;
    }

    final nextState = Map<String, SessionDetails>.from(state);
    nextState.remove(sessionId);
    state = nextState;
  }

  SessionDetails _resolveDetails({
    required String sessionId,
    required String userId,
    required String rootAgentId,
    required String rootAgentName,
    required DateTime fallbackTime,
  }) {
    final current = state[sessionId];
    if (current != null) {
      return current;
    }

    final baseDetails = ref.read(sessionDetailsProvider).valueOrNull;
    if (baseDetails != null && baseDetails.session.id == sessionId) {
      return baseDetails;
    }

    SessionListEntry? baseSession;
    final baseSessions = ref.read(sessionsListProvider).valueOrNull;
    if (baseSessions != null) {
      for (final session in baseSessions) {
        if (session.id == sessionId) {
          baseSession = session;
          break;
        }
      }
    }

    return SessionDetails(
      session: SessionSummary(
        id: sessionId,
        userId: userId,
        title: baseSession?.title,
        status: baseSession?.status ?? 'active',
        createdAt: baseSession?.createdAt ?? fallbackTime,
        updatedAt: baseSession?.updatedAt ?? fallbackTime,
      ),
      rootAgent: RootAgentSummary(
        id: baseSession?.rootAgentId ?? rootAgentId,
        name: baseSession?.rootAgentName ?? rootAgentName,
        status: baseSession?.rootAgentStatus ?? 'running',
        model: 'unknown',
        waitingFor: const <Map<String, Object?>>[],
      ),
      items: const <SessionItem>[],
    );
  }

  int _nextSequence(List<SessionItem> items) {
    var highestSequence = 0;
    for (final item in items) {
      if (item.sequence > highestSequence) {
        highestSequence = item.sequence;
      }
    }
    return highestSequence + 1;
  }

  int? _findStreamingAssistantIndex(
    List<SessionItem> items,
    String? streamingMessageItemId,
  ) {
    if (streamingMessageItemId == null || streamingMessageItemId.isEmpty) {
      return null;
    }

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item is SessionMessageItem && item.id == streamingMessageItemId) {
        return index;
      }
    }

    return null;
  }

  int? _findToolCallIndex(List<SessionItem> items, String callId) {
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item is SessionToolCallItem && item.callId == callId) {
        return index;
      }
    }

    return null;
  }
}

final sessionsListOverlayProvider =
    NotifierProvider<SessionsListOverlayController, List<SessionListEntry>>(
      SessionsListOverlayController.new,
    );

final sessionDetailsOverlayProvider =
    NotifierProvider<
      SessionDetailsOverlayController,
      Map<String, SessionDetails>
    >(SessionDetailsOverlayController.new);

List<SessionListEntry> _mergeSessionLists(
  List<SessionListEntry> base,
  List<SessionListEntry> overlay,
) {
  final overlayIds = overlay.map((session) => session.id).toSet();
  return <SessionListEntry>[
    ...overlay,
    for (final session in base)
      if (!overlayIds.contains(session.id)) session,
  ];
}
