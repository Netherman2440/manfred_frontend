import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manfred/features/chat/application/composer_controller.dart';
import 'package:manfred/features/chat/application/feature_disabled_summarize_provider.dart';
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
import 'package:manfred/features/sessions/domain/session_attachment.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';
import 'package:manfred/features/sessions/domain/session_list_entry.dart';

void main() {
  test('transitions idle -> editing -> streaming for message edit', () async {
    final sessionsRepository = _FakeSessionsRepository(
      sessions: <SessionListEntry>[
        _sessionEntry(lastMessagePreview: 'Edited brief'),
      ],
      details: <String, SessionDetails>{
        'session-1': SessionDetails(
          session: _sessionSummary(),
          rootAgent: _rootAgent(status: 'completed'),
          items: <SessionItem>[
            SessionMessageItem(
              id: 'message-1',
              agentId: 'agent-1',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-30T10:00:00Z'),
              role: 'user',
              content: 'Original brief',
              attachments: const <SessionAttachment>[
                SessionAttachment(
                  id: 'attachment-1',
                  fileName: 'brief.pdf',
                  mediaType: 'application/pdf',
                  sizeBytes: 4096,
                  path: '/uploads/brief.pdf',
                ),
              ],
            ),
            SessionMessageItem(
              id: 'message-2',
              agentId: 'agent-1',
              sequence: 2,
              createdAt: DateTime.parse('2026-04-30T10:00:10Z'),
              role: 'assistant',
              content: 'Initial answer',
            ),
          ],
        ),
      },
    );
    final editedResults = <String, Object?>{};
    final chatRepository = _FakeChatRepository(
      onEditStream:
          ({
            required sessionId,
            required itemId,
            required message,
            required retainAttachmentIds,
            List<PendingAttachment> attachments = const <PendingAttachment>[],
          }) async* {
            editedResults['sessionId'] = sessionId;
            editedResults['itemId'] = itemId;
            editedResults['message'] = message;
            editedResults['retainAttachmentIds'] = retainAttachmentIds;
            editedResults['attachmentCount'] = attachments.length;
            sessionsRepository.setDetails(
              'session-1',
              SessionDetails(
                session: _sessionSummary(),
                rootAgent: _rootAgent(status: 'completed'),
                items: <SessionItem>[
                  SessionMessageItem(
                    id: 'message-1',
                    agentId: 'agent-1',
                    sequence: 1,
                    createdAt: DateTime.parse('2026-04-30T10:00:00Z'),
                    role: 'user',
                    content: message,
                    attachments: const <SessionAttachment>[
                      SessionAttachment(
                        id: 'attachment-1',
                        fileName: 'brief.pdf',
                        mediaType: 'application/pdf',
                        sizeBytes: 4096,
                        path: '/uploads/brief.pdf',
                      ),
                    ],
                    isEdited: true,
                    editedAt: DateTime.parse('2026-04-30T10:01:00Z'),
                  ),
                  SessionMessageItem(
                    id: 'message-3',
                    agentId: 'agent-1',
                    sequence: 2,
                    createdAt: DateTime.parse('2026-04-30T10:01:01Z'),
                    role: 'assistant',
                    content: 'Edited answer',
                  ),
                ],
              ),
            );
            yield const ChatTextDeltaStreamEvent(delta: 'Edited answer');
            yield const ChatDoneStreamEvent();
          },
    );
    final container = _createContainer(
      sessionsRepository: sessionsRepository,
      chatRepository: chatRepository,
    );
    addTearDown(container.dispose);

    container.read(selectedSessionProvider.notifier).select('session-1');
    container
        .read(sessionsListOverlayProvider.notifier)
        .upsert(_sessionEntry(lastMessagePreview: 'Original brief'));
    container
        .read(sessionDetailsOverlayProvider.notifier)
        .replace(sessionsRepository.details['session-1']!);

    final controller = container.read(composerControllerProvider.notifier);
    controller.beginEdit('message-1');

    final editingState = container.read(composerControllerProvider);
    expect(editingState.isEditing, isTrue);
    expect(editingState.draft, isEmpty);
    expect(editingState.attachments, isEmpty);
    expect(editingState.editTarget?.draft, 'Original brief');
    expect(editingState.editTarget?.attachments, hasLength(1));

    controller.updateEditDraft('Edited brief');
    await controller.submitEdit(rootAgentName: 'Manfred');

    final finalState = container.read(composerControllerProvider);
    expect(finalState.isEditing, isFalse);
    expect(finalState.isStreaming, isFalse);
    expect(finalState.draft, isEmpty);
    expect(editedResults['sessionId'], 'session-1');
    expect(editedResults['itemId'], 'message-1');
    expect(editedResults['message'], 'Edited brief');
    expect(editedResults['retainAttachmentIds'], <String>['attachment-1']);
    expect(
      container
          .read(activeSessionDetailsViewProvider)
          .valueOrNull
          ?.items
          .whereType<SessionMessageItem>()
          .first
          .isEdited,
      isTrue,
    );
  });

  test(
    'queues next message during active stream and keeps pending state',
    () async {
      final sessionsRepository = _FakeSessionsRepository(
        sessions: <SessionListEntry>[
          _sessionEntry(lastMessagePreview: 'First message'),
        ],
        details: <String, SessionDetails>{
          'session-1': SessionDetails(
            session: _sessionSummary(),
            rootAgent: _rootAgent(status: 'running'),
            items: const <SessionItem>[],
          ),
        },
      );
      final streamController = StreamController<ChatStreamEvent>();
      final queuedMessages = <QueuedMessage>[];
      final chatRepository = _FakeChatRepository(
        onSendStream:
            ({
              required message,
              String? sessionId,
              List<PendingAttachment> attachments = const <PendingAttachment>[],
            }) {
              return streamController.stream;
            },
        onQueue: ({required message}) async {
          queuedMessages.add(
            message.copyWith(queuedInputId: 'queued-1', position: 1),
          );
          return queuedMessages.single;
        },
      );
      final container = _createContainer(
        sessionsRepository: sessionsRepository,
        chatRepository: chatRepository,
      );
      addTearDown(() async {
        if (!streamController.isClosed) {
          await streamController.close();
        }
        container.dispose();
      });

      container.read(selectedSessionProvider.notifier).select('session-1');
      container
          .read(sessionsListOverlayProvider.notifier)
          .upsert(_sessionEntry(lastMessagePreview: 'First message'));

      final controller = container.read(composerControllerProvider.notifier);
      controller.updateDraft('First message');
      final sendFuture = controller.send(rootAgentName: 'Manfred');

      streamController.add(
        const ChatSessionStartedStreamEvent(
          sessionId: 'session-1',
          agentId: 'agent-1',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.updateDraft('Follow-up question');
      await controller.send(rootAgentName: 'Manfred');

      final queueState = container.read(composerControllerProvider);
      expect(queueState.pendingQueuedMessages, hasLength(1));
      expect(
        queueState.pendingQueuedMessages.single.message,
        'Follow-up question',
      );

      final overlay = container.read(
        sessionDetailsOverlayProvider,
      )['session-1']!;
      final queuedItem = overlay.items.whereType<SessionMessageItem>().last;
      expect(queuedItem.pendingStatus, 'queued');
      expect(queuedItem.content, 'Follow-up question');

      streamController.add(const ChatDoneStreamEvent());
      await streamController.close();
      await sendFuture;

      expect(
        container.read(composerControllerProvider).pendingQueuedMessages,
        hasLength(1),
      );
    },
  );

  group('slash command', () {
    _SlashCommandHarness setUpHarness({
      bool selectSession = true,
      Future<SummarizeResult> Function({required String sessionId})?
      onSummarize,
    }) {
      final sessionsRepository = _FakeSessionsRepository(
        sessions: <SessionListEntry>[_sessionEntry(lastMessagePreview: 'x')],
        details: <String, SessionDetails>{
          'session-1': SessionDetails(
            session: _sessionSummary(),
            rootAgent: _rootAgent(status: 'completed'),
            items: const <SessionItem>[],
          ),
        },
      );
      final chatRepository = _FakeChatRepository(
        onSendStream:
            ({
              required message,
              String? sessionId,
              List<PendingAttachment> attachments = const <PendingAttachment>[],
            }) {
              return Stream<ChatStreamEvent>.fromIterable(
                const <ChatStreamEvent>[ChatDoneStreamEvent()],
              );
            },
        onSummarize:
            onSummarize ??
            ({required sessionId}) async => const SummarizeNoUnobserved(),
      );
      final emitter = _FakeSummarizeSnackbarEmitter();
      final container = _createContainer(
        sessionsRepository: sessionsRepository,
        chatRepository: chatRepository,
        emitter: emitter,
      );
      if (selectSession) {
        container.read(selectedSessionProvider.notifier).select('session-1');
        container
            .read(sessionsListOverlayProvider.notifier)
            .upsert(_sessionEntry(lastMessagePreview: 'x'));
      }
      return _SlashCommandHarness(
        container: container,
        sessionsRepository: sessionsRepository,
        chatRepository: chatRepository,
        emitter: emitter,
      );
    }

    test(
      '/summarize triggers summarize, skips sendMessageStream and clears draft',
      () async {
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeSuccess('preview'),
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send();

        expect(harness.chatRepository.summarizeCallCount, 1);
        expect(harness.chatRepository.summarizeSessionIds, <String>['session-1']);
        expect(harness.chatRepository.sendStreamCallCount, 0);
        expect(
          harness.container.read(composerControllerProvider).draft,
          isEmpty,
        );
      },
    );

    test(
      '/summarize sets runningCommand mid-call and clears after completion',
      () async {
        final completer = Completer<SummarizeResult>();
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) => completer.future,
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        final future = controller.send();
        await Future<void>.delayed(Duration.zero);

        final midState = harness.container.read(composerControllerProvider);
        expect(midState.runningCommand, 'summarize');
        expect(midState.isRunningCommand, isTrue);
        expect(midState.isBusy, isTrue);

        completer.complete(const SummarizeSuccess('preview'));
        await future;

        final finalState = harness.container.read(composerControllerProvider);
        expect(finalState.runningCommand, isNull);
        expect(finalState.isRunningCommand, isFalse);
        expect(finalState.isBusy, isFalse);
      },
    );

    test('/SUMMARIZE (uppercase) also runs the command', () async {
      final harness = setUpHarness(
        onSummarize: ({required sessionId}) async =>
            const SummarizeSuccess('preview'),
      );
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('/SUMMARIZE');
      await controller.send();

      expect(harness.chatRepository.summarizeCallCount, 1);
      expect(harness.chatRepository.sendStreamCallCount, 0);
    });

    test('/summarize with trailing args runs the command, args ignored',
        () async {
      final harness = setUpHarness(
        onSummarize: ({required sessionId}) async =>
            const SummarizeSuccess('preview'),
      );
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('/summarize foo bar');
      await controller.send();

      expect(harness.chatRepository.summarizeCallCount, 1);
      expect(harness.chatRepository.sendStreamCallCount, 0);
    });

    test('/summarize with trailing whitespace still runs the command',
        () async {
      final harness = setUpHarness(
        onSummarize: ({required sessionId}) async =>
            const SummarizeSuccess('preview'),
      );
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('/summarize   ');
      await controller.send();

      expect(harness.chatRepository.summarizeCallCount, 1);
      expect(harness.chatRepository.sendStreamCallCount, 0);
    });

    test('/sum (prefix-only) falls through to sendMessageStream', () async {
      final harness = setUpHarness();
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('/sum');
      await controller.send(rootAgentName: 'Manfred');

      expect(harness.chatRepository.summarizeCallCount, 0);
      expect(harness.chatRepository.sendStreamCallCount, 1);
      expect(harness.chatRepository.sendStreamMessages.single, '/sum');
    });

    test('/unknown falls through to sendMessageStream', () async {
      final harness = setUpHarness();
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('/unknown');
      await controller.send(rootAgentName: 'Manfred');

      expect(harness.chatRepository.summarizeCallCount, 0);
      expect(harness.chatRepository.sendStreamCallCount, 1);
      expect(harness.chatRepository.sendStreamMessages.single, '/unknown');
    });

    test('plain text falls through to sendMessageStream', () async {
      final harness = setUpHarness();
      addTearDown(harness.container.dispose);

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.updateDraft('hello world');
      await controller.send(rootAgentName: 'Manfred');

      expect(harness.chatRepository.summarizeCallCount, 0);
      expect(harness.chatRepository.sendStreamCallCount, 1);
      expect(harness.chatRepository.sendStreamMessages.single, 'hello world');
    });

    test(
      '503 result sticky-disables the session via featureDisabledSummarizeProvider',
      () async {
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeFeatureDisabled(),
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send();

        expect(
          harness.container.read(featureDisabledSummarizeProvider),
          contains('session-1'),
        );
      },
    );

    test(
      '/summarize falls through to sendMessageStream when sticky-disabled for the session',
      () async {
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeSuccess('should not be called'),
        );
        addTearDown(harness.container.dispose);

        harness.container
            .read(featureDisabledSummarizeProvider.notifier)
            .update((set) => <String>{...set, 'session-1'});

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send(rootAgentName: 'Manfred');

        expect(harness.chatRepository.summarizeCallCount, 0);
        expect(harness.chatRepository.sendStreamCallCount, 1);
        expect(harness.chatRepository.sendStreamMessages.single, '/summarize');
        expect(harness.emitter.recorded, isEmpty);
      },
    );

    for (final entry in <(String, SummarizeResult)>[
      ('success', SummarizeSuccess('preview')),
      ('locked', SummarizeLocked()),
      ('belowThreshold', SummarizeBelowThreshold('1 < 1000')),
      ('error', SummarizeError('boom')),
      ('notFound', SummarizeNotFound()),
      ('featureDisabled', SummarizeFeatureDisabled()),
      ('transportError', SummarizeTransportError('timeout')),
    ]) {
      test('result variant ${entry.$1} is emitted to the snackbar emitter',
          () async {
        final result = entry.$2;
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) async => result,
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send();

        expect(harness.emitter.recorded, hasLength(1));
        expect(harness.emitter.recorded.single.result, same(result));
      });
    }

    test(
      'SummarizeNoUnobserved (204) is also emitted to the emitter (renderer decides UX)',
      () async {
        final harness = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeNoUnobserved(),
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send();

        expect(harness.emitter.recorded, hasLength(1));
        expect(
          harness.emitter.recorded.single.result,
          isA<SummarizeNoUnobserved>(),
        );
      },
    );

    test(
      'SummarizeError result includes an onRetry callback; other variants do not',
      () async {
        final harnessError = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeError('boom'),
        );
        addTearDown(harnessError.container.dispose);

        final controllerError = harnessError.container.read(
          composerControllerProvider.notifier,
        );
        controllerError.updateDraft('/summarize');
        await controllerError.send();
        expect(harnessError.emitter.recorded.single.onRetry, isNotNull);

        final harnessSuccess = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeSuccess('preview'),
        );
        addTearDown(harnessSuccess.container.dispose);

        final controllerSuccess = harnessSuccess.container.read(
          composerControllerProvider.notifier,
        );
        controllerSuccess.updateDraft('/summarize');
        await controllerSuccess.send();
        expect(harnessSuccess.emitter.recorded.single.onRetry, isNull);

        final harnessTransport = setUpHarness(
          onSummarize: ({required sessionId}) async =>
              const SummarizeTransportError('timeout'),
        );
        addTearDown(harnessTransport.container.dispose);

        final controllerTransport = harnessTransport.container.read(
          composerControllerProvider.notifier,
        );
        controllerTransport.updateDraft('/summarize');
        await controllerTransport.send();
        expect(harnessTransport.emitter.recorded.single.onRetry, isNull);
      },
    );

    test('isEditing blocks slash commands too', () async {
      final harness = setUpHarness(
        onSummarize: ({required sessionId}) async =>
            const SummarizeSuccess('preview'),
      );
      addTearDown(harness.container.dispose);

      harness.container
          .read(sessionDetailsOverlayProvider.notifier)
          .replace(harness.sessionsRepository.details['session-1']!);
      harness.container
          .read(sessionDetailsOverlayProvider.notifier)
          .replace(
            SessionDetails(
              session: _sessionSummary(),
              rootAgent: _rootAgent(status: 'completed'),
              items: <SessionItem>[
                SessionMessageItem(
                  id: 'message-1',
                  agentId: 'agent-1',
                  sequence: 1,
                  createdAt: DateTime.parse('2026-04-30T10:00:00Z'),
                  role: 'user',
                  content: 'Original brief',
                ),
              ],
            ),
          );

      final controller = harness.container.read(
        composerControllerProvider.notifier,
      );
      controller.beginEdit('message-1');
      expect(
        harness.container.read(composerControllerProvider).isEditing,
        isTrue,
      );

      controller.updateDraft('/summarize');
      await controller.send();

      expect(harness.chatRepository.summarizeCallCount, 0);
      expect(
        harness.container.read(composerControllerProvider).errorMessage,
        isNotNull,
      );
    });

    test(
      'slash command with no active session sets errorMessage and skips summarize',
      () async {
        final harness = setUpHarness(
          selectSession: false,
          onSummarize: ({required sessionId}) async =>
              const SummarizeSuccess('preview'),
        );
        addTearDown(harness.container.dispose);

        final controller = harness.container.read(
          composerControllerProvider.notifier,
        );
        controller.updateDraft('/summarize');
        await controller.send();

        expect(harness.chatRepository.summarizeCallCount, 0);
        final composerState = harness.container.read(composerControllerProvider);
        expect(composerState.errorMessage, isNotNull);
        expect(composerState.errorMessage, contains('sesję'));
      },
    );
  });
}

class _SlashCommandHarness {
  _SlashCommandHarness({
    required this.container,
    required this.sessionsRepository,
    required this.chatRepository,
    required this.emitter,
  });

  final ProviderContainer container;
  final _FakeSessionsRepository sessionsRepository;
  final _FakeChatRepository chatRepository;
  final _FakeSummarizeSnackbarEmitter emitter;
}

ProviderContainer _createContainer({
  required SessionsRepository sessionsRepository,
  required ChatRepository chatRepository,
  SummarizeSnackbarEmitter? emitter,
}) {
  return ProviderContainer(
    overrides: <Override>[
      sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
      chatRepositoryProvider.overrideWithValue(chatRepository),
      summarizeSnackbarEmitterProvider.overrideWithValue(
        emitter ?? _FakeSummarizeSnackbarEmitter(),
      ),
    ],
  );
}

SessionListEntry _sessionEntry({required String lastMessagePreview}) {
  return SessionListEntry(
    id: 'session-1',
    userId: 'default-user',
    title: 'chat',
    status: 'active',
    rootAgentId: 'agent-1',
    rootAgentName: 'Manfred',
    rootAgentStatus: 'running',
    waitingForCount: 0,
    lastMessagePreview: lastMessagePreview,
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

RootAgentSummary _rootAgent({required String status}) {
  return RootAgentSummary(
    id: 'agent-1',
    name: 'Manfred',
    status: status,
    model: 'openrouter:test',
    waitingFor: const <Map<String, Object?>>[],
  );
}

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository({
    required List<SessionListEntry> sessions,
    required Map<String, SessionDetails> details,
  }) : _sessions = List<SessionListEntry>.from(sessions),
       details = Map<String, SessionDetails>.from(details);

  final List<SessionListEntry> _sessions;
  final Map<String, SessionDetails> details;

  @override
  Future<SessionDetails> fetchSessionDetails(
    String userId,
    String sessionId,
  ) async {
    return details[sessionId]!;
  }

  @override
  Future<List<SessionListEntry>> fetchSessions(String userId) async {
    return List<SessionListEntry>.from(_sessions);
  }

  void setDetails(String sessionId, SessionDetails value) {
    details[sessionId] = value;
  }
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.onSendStream,
    this.onQueue,
    this.onEditStream,
    this.onSummarize,
  });

  final Stream<ChatStreamEvent> Function({
    required String message,
    String? sessionId,
    List<PendingAttachment> attachments,
  })?
  onSendStream;
  final Future<QueuedMessage> Function({required QueuedMessage message})?
  onQueue;
  final Stream<ChatStreamEvent> Function({
    required String sessionId,
    required String itemId,
    required String message,
    required List<String> retainAttachmentIds,
    List<PendingAttachment> attachments,
  })?
  onEditStream;
  final Future<SummarizeResult> Function({required String sessionId})?
  onSummarize;

  int sendStreamCallCount = 0;
  int summarizeCallCount = 0;
  final List<String?> sendStreamMessages = <String?>[];
  final List<String> summarizeSessionIds = <String>[];

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
    return onSendStream!(
      message: message,
      sessionId: sessionId,
      attachments: attachments,
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
  Future<QueuedMessage> queueMessage({required QueuedMessage message}) {
    return onQueue!(message: message);
  }

  @override
  Stream<ChatStreamEvent> editMessageStream({
    required String sessionId,
    required String itemId,
    required String message,
    required List<String> retainAttachmentIds,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) {
    return onEditStream!(
      sessionId: sessionId,
      itemId: itemId,
      message: message,
      retainAttachmentIds: retainAttachmentIds,
      attachments: attachments,
    );
  }

  @override
  Future<SummarizeResult> summarize({required String sessionId}) {
    summarizeCallCount += 1;
    summarizeSessionIds.add(sessionId);
    return onSummarize!(sessionId: sessionId);
  }
}

class _RecordedSnackbar {
  const _RecordedSnackbar({required this.result, required this.onRetry});

  final SummarizeResult result;
  final VoidCallback? onRetry;
}

class _FakeSummarizeSnackbarEmitter implements SummarizeSnackbarEmitter {
  final List<_RecordedSnackbar> recorded = <_RecordedSnackbar>[];

  @override
  void show(SummarizeResult result, {VoidCallback? onRetry}) {
    recorded.add(_RecordedSnackbar(result: result, onRetry: onRetry));
  }
}
