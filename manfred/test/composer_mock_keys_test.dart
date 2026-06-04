import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/chat/application/composer_controller.dart';
import 'package:manfred/features/chat/application/summarize_snackbar_emitter.dart';
import 'package:manfred/features/chat/data/chat_repository.dart';
import 'package:manfred/features/chat/domain/chat_mutation_result.dart';
import 'package:manfred/features/chat/domain/chat_stream_event.dart';
import 'package:manfred/features/chat/domain/pending_attachment.dart';
import 'package:manfred/features/chat/domain/queued_message.dart';
import 'package:manfred/features/chat/domain/summarize_result.dart';
import 'package:manfred/features/sessions/application/selected_session_provider.dart';
import 'package:manfred/features/sessions/application/session_overlay_providers.dart';
import 'package:manfred/features/sessions/data/sessions_repository.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';
import 'package:manfred/features/sessions/domain/session_list_entry.dart';
import 'package:manfred/ui/screens/chat_workspace/controls/composer_mock.dart';
import 'package:manfred/ui/theme/manfred_theme.dart';

void main() {
  Future<_Harness> pumpComposer(WidgetTester tester) async {
    final sessionsRepository = _FakeSessionsRepository(
      sessions: <SessionListEntry>[_entry()],
      details: <String, SessionDetails>{
        'session-1': SessionDetails(
          session: _sessionSummary(),
          rootAgent: _rootAgent(),
          items: const <SessionItem>[],
        ),
      },
    );
    final chatRepository = _FakeChatRepository();
    final emitter = _FakeSummarizeSnackbarEmitter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
          chatRepositoryProvider.overrideWithValue(chatRepository),
          summarizeSnackbarEmitterProvider.overrideWithValue(emitter),
        ],
        child: MaterialApp(
          theme: ManfredTheme.dark(),
          home: const Scaffold(
            body: ComposerMock(
              showCompactLayout: false,
              rootAgentName: 'Manfred',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(ComposerMock));
    final container = ProviderScope.containerOf(element);
    container.read(selectedSessionProvider.notifier).select('session-1');
    container.read(sessionsListOverlayProvider.notifier).upsert(_entry());
    await tester.pumpAndSettle();

    return _Harness(container: container, chatRepository: chatRepository);
  }

  Future<void> typeIntoComposer(WidgetTester tester, String text) async {
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('TextInputAction.send (IME / soft-keyboard) triggers send',
      (tester) async {
    final harness = await pumpComposer(tester);
    addTearDown(harness.container.dispose);

    await typeIntoComposer(tester, 'hello world');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(harness.chatRepository.sendStreamCallCount, 1);
    expect(harness.chatRepository.sendStreamMessages.single, 'hello world');
  });

  testWidgets('Shift+Enter inserts newline and does NOT send', (tester) async {
    final harness = await pumpComposer(tester);
    addTearDown(harness.container.dispose);

    await typeIntoComposer(tester, 'hello');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(harness.chatRepository.sendStreamCallCount, 0);
    final draft = harness.container.read(composerControllerProvider).draft;
    expect(draft, 'hello\n');
  });

  testWidgets(
    'Shift+Enter while slash palette is open still inserts newline',
    (tester) async {
      final harness = await pumpComposer(tester);
      addTearDown(harness.container.dispose);

      await typeIntoComposer(tester, '/sum');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(harness.chatRepository.sendStreamCallCount, 0);
      expect(harness.chatRepository.summarizeCallCount, 0);
      final draft = harness.container.read(composerControllerProvider).draft;
      expect(draft, '/sum\n');
    },
  );
}

class _Harness {
  _Harness({required this.container, required this.chatRepository});

  final ProviderContainer container;
  final _FakeChatRepository chatRepository;
}

SessionListEntry _entry() {
  return SessionListEntry(
    id: 'session-1',
    userId: 'default-user',
    title: 'chat',
    status: 'active',
    rootAgentId: 'agent-1',
    rootAgentName: 'Manfred',
    rootAgentStatus: 'running',
    waitingForCount: 0,
    lastMessagePreview: '',
    createdAt: DateTime.parse('2026-04-30T10:00:00Z'),
    updatedAt: DateTime.parse('2026-04-30T10:00:00Z'),
  );
}

SessionSummary _sessionSummary() {
  return SessionSummary(
    id: 'session-1',
    userId: 'default-user',
    title: 'chat',
    status: 'active',
    createdAt: DateTime.parse('2026-04-30T10:00:00Z'),
    updatedAt: DateTime.parse('2026-04-30T10:00:00Z'),
  );
}

RootAgentSummary _rootAgent() {
  return RootAgentSummary(
    id: 'agent-1',
    name: 'Manfred',
    status: 'completed',
    model: 'openrouter:test',
    waitingFor: const <Map<String, Object?>>[],
  );
}

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository({
    required List<SessionListEntry> sessions,
    required Map<String, SessionDetails> details,
  })  : _sessions = List<SessionListEntry>.from(sessions),
        _details = Map<String, SessionDetails>.from(details);

  final List<SessionListEntry> _sessions;
  final Map<String, SessionDetails> _details;

  @override
  Future<SessionDetails> fetchSessionDetails(
    String userId,
    String sessionId,
  ) async {
    return _details[sessionId]!;
  }

  @override
  Future<List<SessionListEntry>> fetchSessions(String userId) async {
    return List<SessionListEntry>.from(_sessions);
  }
}

class _FakeChatRepository implements ChatRepository {
  int sendStreamCallCount = 0;
  int summarizeCallCount = 0;
  final List<String> sendStreamMessages = <String>[];

  @override
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
    String? agentName,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) {
    sendStreamCallCount += 1;
    sendStreamMessages.add(message);
    return Stream<ChatStreamEvent>.fromIterable(
      const <ChatStreamEvent>[ChatDoneStreamEvent()],
    );
  }

  @override
  Stream<ChatStreamEvent> deliverMessageStream({
    required String agentId,
    required String callId,
    required String message,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChatMutationResult> cancelRun({required String sessionId}) async {
    return const ChatMutationResult(
      sessionId: 'session-1',
      agentId: 'agent-1',
      status: 'cancelled',
      error: null,
    );
  }

  @override
  Future<QueuedMessage> queueMessage({required QueuedMessage message}) async {
    throw UnimplementedError();
  }

  @override
  Stream<ChatStreamEvent> editMessageStream({
    required String sessionId,
    required String itemId,
    required String message,
    required List<String> retainAttachmentIds,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SummarizeResult> summarize({required String sessionId}) async {
    summarizeCallCount += 1;
    return const SummarizeSuccess('preview');
  }
}

class _FakeSummarizeSnackbarEmitter implements SummarizeSnackbarEmitter {
  @override
  void show(SummarizeResult result, {VoidCallback? onRetry}) {}
}
