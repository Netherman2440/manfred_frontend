import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/chat/data/chat_repository.dart';
import 'package:manfred/features/chat/domain/chat_mutation_result.dart';
import 'package:manfred/features/chat/domain/chat_stream_event.dart';
import 'package:manfred/features/sessions/data/sessions_repository.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';
import 'package:manfred/features/sessions/domain/session_list_entry.dart';
import 'package:manfred/ui/screens/chat_workspace/chat_workspace_page.dart';
import 'package:manfred/ui/theme/manfred_theme.dart';

void main() {
  testWidgets('loads sessions from repository and renders transcript items', (
    WidgetTester tester,
  ) async {
    final sessionsRepository = FakeSessionsRepository(
      sessions: <SessionListEntry>[
        SessionListEntry(
          id: 'session-1',
          userId: 'default-user',
          title: 'ui-foundation',
          status: 'active',
          rootAgentId: 'agent-1',
          rootAgentName: 'Manfred',
          rootAgentStatus: 'completed',
          waitingForCount: 0,
          lastMessagePreview: 'Mam już szkic integracji.',
          createdAt: DateTime.parse('2026-04-17T10:00:00Z'),
          updatedAt: DateTime.parse('2026-04-17T10:05:00Z'),
        ),
      ],
      details: <String, SessionDetails>{
        'session-1': SessionDetails(
          session: SessionSummary(
            id: 'session-1',
            userId: 'default-user',
            title: 'ui-foundation',
            status: 'active',
            createdAt: DateTime.parse('2026-04-17T10:00:00Z'),
            updatedAt: DateTime.parse('2026-04-17T10:05:00Z'),
          ),
          rootAgent: const RootAgentSummary(
            id: 'agent-1',
            name: 'Manfred',
            status: 'completed',
            model: 'openrouter:test-model',
            waitingFor: <Map<String, Object?>>[],
          ),
          items: <SessionItem>[
            SessionMessageItem(
              id: 'item-1',
              agentId: 'agent-1',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-17T10:00:00Z'),
              role: 'user',
              content: 'Potrzebuję planu wdrożenia.',
            ),
            SessionToolCallItem(
              id: 'item-2',
              agentId: 'agent-1',
              sequence: 2,
              createdAt: DateTime.parse('2026-04-17T10:01:00Z'),
              callId: 'call-1',
              name: 'search_docs',
              arguments: <String, Object?>{'query': 'sessions api'},
            ),
            SessionToolResultItem(
              id: 'item-3',
              agentId: 'agent-1',
              sequence: 3,
              createdAt: DateTime.parse('2026-04-17T10:01:01Z'),
              callId: 'call-1',
              name: 'search_docs',
              toolResult: <String, Object?>{
                'ok': true,
                'output': <String, Object?>{'hits': 3},
              },
              isError: false,
            ),
            SessionMessageItem(
              id: 'item-4',
              agentId: 'agent-1',
              sequence: 4,
              createdAt: DateTime.parse('2026-04-17T10:02:00Z'),
              role: 'assistant',
              content: 'Mam już szkic integracji.',
            ),
          ],
        ),
      },
    );

    await _pumpWorkspace(
      tester,
      sessionsRepository: sessionsRepository,
      chatRepository: FakeChatRepository(
        onSend: ({required message, required sessionId}) async {
          return const ChatMutationResult(
            sessionId: 'session-1',
            agentId: 'agent-1',
            status: 'completed',
            error: null,
          );
        },
        onDeliver:
            ({required agentId, required callId, required message}) async {
              throw UnimplementedError(
                'deliver should not be called in this test',
              );
            },
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsWidgets);
    expect(find.text('ui-foundation'), findsWidgets);
    expect(find.text('Potrzebuję planu wdrożenia.'), findsOneWidget);
    expect(find.text('Mam już szkic integracji.'), findsWidgets);
    expect(find.text('search_docs'), findsOneWidget);
    expect(find.text('Artifacts'), findsOneWidget);
  });

  testWidgets('new session first send switches to created session', (
    WidgetTester tester,
  ) async {
    final sessionsRepository = FakeSessionsRepository(
      sessions: <SessionListEntry>[
        SessionListEntry(
          id: 'session-existing',
          userId: 'default-user',
          title: 'existing',
          status: 'active',
          rootAgentId: 'agent-existing',
          rootAgentName: 'Manfred',
          rootAgentStatus: 'completed',
          waitingForCount: 0,
          lastMessagePreview: 'Existing transcript',
          createdAt: DateTime.parse('2026-04-17T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-17T09:05:00Z'),
        ),
      ],
      details: <String, SessionDetails>{
        'session-existing': SessionDetails(
          session: SessionSummary(
            id: 'session-existing',
            userId: 'default-user',
            title: 'existing',
            status: 'active',
            createdAt: DateTime.parse('2026-04-17T09:00:00Z'),
            updatedAt: DateTime.parse('2026-04-17T09:05:00Z'),
          ),
          rootAgent: const RootAgentSummary(
            id: 'agent-existing',
            name: 'Manfred',
            status: 'completed',
            model: 'openrouter:test-model',
            waitingFor: <Map<String, Object?>>[],
          ),
          items: const <SessionItem>[],
        ),
      },
    );

    final chatRepository = FakeChatRepository(
      onSend: ({required message, required sessionId}) async {
        throw UnimplementedError('sync send should not be used in this test');
      },
      onSendStream: ({required message, String? sessionId}) async* {
        expect(sessionId, isNull);
        sessionsRepository.upsertSession(
          SessionListEntry(
            id: 'session-created',
            userId: 'default-user',
            title: 'created-session',
            status: 'active',
            rootAgentId: 'agent-created',
            rootAgentName: 'Manfred',
            rootAgentStatus: 'completed',
            waitingForCount: 0,
            lastMessagePreview: message,
            createdAt: DateTime.parse('2026-04-17T11:00:00Z'),
            updatedAt: DateTime.parse('2026-04-17T11:00:01Z'),
          ),
        );
        sessionsRepository.setDetails(
          'session-created',
          SessionDetails(
            session: SessionSummary(
              id: 'session-created',
              userId: 'default-user',
              title: 'created-session',
              status: 'active',
              createdAt: DateTime.parse('2026-04-17T11:00:00Z'),
              updatedAt: DateTime.parse('2026-04-17T11:00:01Z'),
            ),
            rootAgent: const RootAgentSummary(
              id: 'agent-created',
              name: 'Manfred',
              status: 'completed',
              model: 'openrouter:test-model',
              waitingFor: <Map<String, Object?>>[],
            ),
            items: <SessionItem>[
              SessionMessageItem(
                id: 'created-user',
                agentId: 'agent-created',
                sequence: 1,
                createdAt: DateTime.parse('2026-04-17T11:00:00Z'),
                role: 'user',
                content: message,
              ),
              SessionMessageItem(
                id: 'created-assistant',
                agentId: 'agent-created',
                sequence: 2,
                createdAt: DateTime.parse('2026-04-17T11:00:01Z'),
                role: 'assistant',
                content: 'Nowa sesja została utworzona.',
              ),
            ],
          ),
        );

        yield const ChatSessionStartedStreamEvent(
          sessionId: 'session-created',
          agentId: 'agent-created',
        );
        yield const ChatDoneStreamEvent();
      },
      onDeliver: ({required agentId, required callId, required message}) async {
        throw UnimplementedError('deliver should not be called in this test');
      },
    );

    await _pumpWorkspace(
      tester,
      sessionsRepository: sessionsRepository,
      chatRepository: chatRepository,
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New session').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Nowa sesja jest pusta. Wyślij pierwszą wiadomość.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Pierwsza wiadomość');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('created-session'), findsWidgets);
    expect(find.text('Pierwsza wiadomość'), findsOneWidget);
    expect(find.text('Nowa sesja została utworzona.'), findsOneWidget);
  });
  testWidgets('waiting reply shows banner and routes send through deliver', (
    WidgetTester tester,
  ) async {
    final sessionsRepository = FakeSessionsRepository(
      sessions: <SessionListEntry>[
        SessionListEntry(
          id: 'session-1',
          userId: 'default-user',
          title: 'delegate-preview',
          status: 'active',
          rootAgentId: 'agent-root',
          rootAgentName: 'Manfred',
          rootAgentStatus: 'waiting',
          waitingForCount: 1,
          lastMessagePreview: 'O jaki zamek chodzi?',
          createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-22T09:02:00Z'),
        ),
      ],
      details: <String, SessionDetails>{
        'session-1': SessionDetails(
          session: SessionSummary(
            id: 'session-1',
            userId: 'default-user',
            title: 'delegate-preview',
            status: 'active',
            createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
            updatedAt: DateTime.parse('2026-04-22T09:02:00Z'),
          ),
          rootAgent: const RootAgentSummary(
            id: 'agent-root',
            name: 'Manfred',
            status: 'waiting',
            model: 'openrouter:test-model',
            waitingFor: <Map<String, Object?>>[
              <String, Object?>{
                'call_id': 'call-parent',
                'type': 'agent',
                'name': 'delegate',
                'description': 'O jaki zamek chodzi?',
                'agent_id': 'agent-research',
              },
            ],
          ),
          items: <SessionItem>[
            SessionToolCallItem(
              id: 'delegate-call',
              agentId: 'agent-root',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-22T09:00:30Z'),
              callId: 'call-parent',
              name: 'delegate',
              arguments: <String, Object?>{
                'agent_name': 'research',
                'task': 'Zbierz informacje o zamku.',
              },
            ),
            SessionMessageItem(
              id: 'worker-user',
              agentId: 'agent-research',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-22T09:01:00Z'),
              role: 'user',
              content: 'Zbierz informacje o zamku.',
            ),
            SessionToolCallItem(
              id: 'worker-ask-user',
              agentId: 'agent-research',
              sequence: 2,
              createdAt: DateTime.parse('2026-04-22T09:01:30Z'),
              callId: 'call-child',
              name: 'ask_user',
              arguments: <String, Object?>{'question': 'O jaki zamek chodzi?'},
            ),
          ],
        ),
      },
    );

    var sendCalls = 0;
    var deliverCalls = 0;
    final chatRepository = FakeChatRepository(
      onSend: ({required message, required sessionId}) async {
        sendCalls += 1;
        return const ChatMutationResult(
          sessionId: 'session-1',
          agentId: 'agent-root',
          status: 'completed',
          error: null,
        );
      },
      onDeliver: ({required agentId, required callId, required message}) async {
        deliverCalls += 1;
        expect(agentId, 'agent-root');
        expect(callId, 'call-parent');
        expect(message, 'Chodzi o zamek w Malborku.');

        sessionsRepository.setDetails(
          'session-1',
          SessionDetails(
            session: SessionSummary(
              id: 'session-1',
              userId: 'default-user',
              title: 'delegate-preview',
              status: 'active',
              createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
              updatedAt: DateTime.parse('2026-04-22T09:03:00Z'),
            ),
            rootAgent: const RootAgentSummary(
              id: 'agent-root',
              name: 'Manfred',
              status: 'completed',
              model: 'openrouter:test-model',
              waitingFor: <Map<String, Object?>>[],
            ),
            items: <SessionItem>[
              SessionMessageItem(
                id: 'resolved-message',
                agentId: 'agent-root',
                sequence: 3,
                createdAt: DateTime.parse('2026-04-22T09:03:00Z'),
                role: 'assistant',
                content: 'Dzięki, już szukam informacji o Malborku.',
              ),
            ],
          ),
        );

        return const ChatMutationResult(
          sessionId: 'session-1',
          agentId: 'agent-root',
          status: 'completed',
          error: null,
        );
      },
    );

    await _pumpWorkspace(
      tester,
      sessionsRepository: sessionsRepository,
      chatRepository: chatRepository,
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Odpowiadasz do @research'), findsOneWidget);
    expect(find.text('O jaki zamek chodzi?'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Chodzi o zamek w Malborku.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(sendCalls, 0);
    expect(deliverCalls, 1);
    expect(find.text('Odpowiadasz do @research'), findsNothing);
    expect(
      find.text('Dzięki, już szukam informacji o Malborku.'),
      findsOneWidget,
    );
  });

  testWidgets('streaming run shows partial answer and stop action', (
    WidgetTester tester,
  ) async {
    final sessionsRepository = FakeSessionsRepository(
      sessions: <SessionListEntry>[
        SessionListEntry(
          id: 'session-1',
          userId: 'default-user',
          title: 'streaming',
          status: 'active',
          rootAgentId: 'agent-root',
          rootAgentName: 'Manfred',
          rootAgentStatus: 'running',
          waitingForCount: 0,
          lastMessagePreview: 'Previous answer',
          createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-22T09:02:00Z'),
        ),
      ],
      details: <String, SessionDetails>{
        'session-1': SessionDetails(
          session: SessionSummary(
            id: 'session-1',
            userId: 'default-user',
            title: 'streaming',
            status: 'active',
            createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
            updatedAt: DateTime.parse('2026-04-22T09:02:00Z'),
          ),
          rootAgent: const RootAgentSummary(
            id: 'agent-root',
            name: 'Manfred',
            status: 'running',
            model: 'openrouter:test-model',
            waitingFor: <Map<String, Object?>>[],
          ),
          items: <SessionItem>[
            SessionMessageItem(
              id: 'item-1',
              agentId: 'agent-root',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
              role: 'assistant',
              content: 'Previous answer',
            ),
          ],
        ),
      },
    );

    final streamController = StreamController<ChatStreamEvent>();
    var cancelCalls = 0;
    final chatRepository = FakeChatRepository(
      onSend: ({required message, required sessionId}) async {
        throw UnimplementedError('sync send should not be used in this test');
      },
      onSendStream: ({required message, String? sessionId}) {
        expect(message, 'Pokaż stream.');
        expect(sessionId, 'session-1');
        return streamController.stream;
      },
      onDeliver: ({required agentId, required callId, required message}) async {
        throw UnimplementedError('deliver should not be used in this test');
      },
      onCancel: ({required sessionId}) async {
        cancelCalls += 1;
        expect(sessionId, 'session-1');
        sessionsRepository.setDetails(
          'session-1',
          SessionDetails(
            session: SessionSummary(
              id: 'session-1',
              userId: 'default-user',
              title: 'streaming',
              status: 'active',
              createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
              updatedAt: DateTime.parse('2026-04-22T09:03:00Z'),
            ),
            rootAgent: const RootAgentSummary(
              id: 'agent-root',
              name: 'Manfred',
              status: 'cancelled',
              model: 'openrouter:test-model',
              waitingFor: <Map<String, Object?>>[],
            ),
            items: <SessionItem>[
              SessionMessageItem(
                id: 'item-1',
                agentId: 'agent-root',
                sequence: 1,
                createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
                role: 'assistant',
                content: 'Previous answer',
              ),
              SessionMessageItem(
                id: 'item-2',
                agentId: 'agent-root',
                sequence: 2,
                createdAt: DateTime.parse('2026-04-22T09:03:00Z'),
                role: 'assistant',
                content: 'Run cancelled.',
              ),
            ],
          ),
        );
        return const ChatMutationResult(
          sessionId: 'session-1',
          agentId: 'agent-root',
          status: 'cancelled',
          error: null,
        );
      },
    );

    await _pumpWorkspace(
      tester,
      sessionsRepository: sessionsRepository,
      chatRepository: chatRepository,
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Pokaż stream.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.byTooltip('Stop'), findsOneWidget);
    expect(find.text('Pokaż stream.'), findsOneWidget);
    expect(find.text('Generowanie odpowiedzi...'), findsOneWidget);

    streamController.add(const ChatTextDeltaStreamEvent(delta: 'To jest '));
    await tester.pump();
    streamController.add(const ChatTextDeltaStreamEvent(delta: 'odpowiedź.'));
    await tester.pump();

    expect(find.text('To jest odpowiedź.'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(cancelCalls, 1);

    await streamController.close();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Stop'), findsNothing);
    expect(find.text('Run cancelled.'), findsOneWidget);
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required SessionsRepository sessionsRepository,
  required ChatRepository chatRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
        chatRepositoryProvider.overrideWithValue(chatRepository),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ManfredTheme.dark(),
        home: const ChatWorkspacePage(),
      ),
    ),
  );
}

class FakeSessionsRepository implements SessionsRepository {
  FakeSessionsRepository({
    required List<SessionListEntry> sessions,
    required Map<String, SessionDetails> details,
  }) : _sessions = List<SessionListEntry>.from(sessions),
       _details = Map<String, SessionDetails>.from(details);

  final List<SessionListEntry> _sessions;
  final Map<String, SessionDetails> _details;

  @override
  Future<SessionDetails> fetchSessionDetails(
    String userId,
    String sessionId,
  ) async {
    final details = _details[sessionId];
    if (details == null) {
      throw StateError('Missing details for $sessionId');
    }

    return details;
  }

  @override
  Future<List<SessionListEntry>> fetchSessions(String userId) async {
    return List<SessionListEntry>.from(_sessions);
  }

  void upsertSession(SessionListEntry session) {
    _sessions.removeWhere((entry) => entry.id == session.id);
    _sessions.insert(0, session);
  }

  void setDetails(String sessionId, SessionDetails details) {
    _details[sessionId] = details;
  }
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    required this.onSend,
    this.onDeliver,
    this.onSendStream,
    this.onCancel,
  });

  final Future<ChatMutationResult> Function({
    required String message,
    required String? sessionId,
  })
  onSend;
  final Stream<ChatStreamEvent> Function({
    required String message,
    String? sessionId,
  })?
  onSendStream;
  final Future<ChatMutationResult> Function({
    required String agentId,
    required String callId,
    required String message,
  })?
  onDeliver;
  final Future<ChatMutationResult> Function({required String sessionId})?
  onCancel;

  @override
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  }) {
    return onSend(message: message, sessionId: sessionId);
  }

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
  }) {
    if (onSendStream == null) {
      throw UnimplementedError('stream send should not be used in this test');
    }
    return onSendStream!(message: message, sessionId: sessionId);
  }

  @override
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  }) {
    if (onDeliver == null) {
      throw UnimplementedError('deliver should not be used in this test');
    }
    return onDeliver!(agentId: agentId, callId: callId, message: message);
  }

  @override
  Future<ChatMutationResult> cancelRun({required String sessionId}) {
    if (onCancel == null) {
      throw UnimplementedError('cancel should not be used in this test');
    }
    return onCancel!(sessionId: sessionId);
  }
}
