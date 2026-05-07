import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manfred/features/chat/application/composer_controller.dart';
import 'package:manfred/features/chat/data/chat_repository.dart';
import 'package:manfred/features/chat/domain/chat_mutation_result.dart';
import 'package:manfred/features/chat/domain/chat_stream_event.dart';
import 'package:manfred/features/chat/domain/pending_attachment.dart';
import 'package:manfred/features/chat/domain/queued_message.dart';
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
}

ProviderContainer _createContainer({
  required SessionsRepository sessionsRepository,
  required ChatRepository chatRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
      chatRepositoryProvider.overrideWithValue(chatRepository),
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
  _FakeChatRepository({this.onSendStream, this.onQueue, this.onEditStream});

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
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) {
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
}
