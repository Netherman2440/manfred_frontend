import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../sessions/application/session_details_provider.dart';
import '../../sessions/application/session_overlay_providers.dart';
import '../../sessions/application/sessions_list_provider.dart';
import '../../sessions/application/selected_session_provider.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../sessions/domain/session_attachment.dart';
import '../../sessions/domain/session_details.dart';
import '../../sessions/domain/session_item.dart';
import '../../sessions/domain/session_list_entry.dart';
import '../../user/application/user_context_provider.dart';
import '../data/chat_repository.dart';
import '../domain/chat_stream_event.dart';
import '../domain/composer_state.dart';
import '../domain/edit_target.dart';
import '../domain/pending_attachment.dart';
import '../domain/queued_message.dart';

class ComposerController extends Notifier<ComposerState> {
  @override
  ComposerState build() => const ComposerState.initial();

  void updateDraft(String value) {
    state = state.copyWith(draft: value, clearErrorMessage: true);
  }

  void resetDraft() {
    state = state.copyWith(
      draft: '',
      clearErrorMessage: true,
      clearAttachments: true,
      clearEditTarget: true,
    );
  }

  void addAttachments(List<PendingAttachment> attachments) {
    state = state.copyWith(
      attachments: <PendingAttachment>[...state.attachments, ...attachments],
      clearErrorMessage: true,
    );
  }

  void removeAttachment(String localId) {
    state = state.copyWith(
      attachments: state.attachments
          .where((attachment) => attachment.localId != localId)
          .toList(growable: false),
      clearErrorMessage: true,
    );
  }

  void cancelEditing() {
    state = state.copyWith(clearEditTarget: true, clearErrorMessage: true);
  }

  void updateEditDraft(String value) {
    final editTarget = state.editTarget;
    if (editTarget == null) {
      return;
    }

    state = state.copyWith(
      editTarget: editTarget.copyWith(draft: value),
      clearErrorMessage: true,
    );
  }

  void beginEdit(String itemId) {
    if (state.isStreaming) {
      state = state.copyWith(
        errorMessage: 'Zatrzymaj aktywny stream przed edycją wiadomości.',
      );
      return;
    }
    if (state.hasQueuedMessages) {
      state = state.copyWith(
        errorMessage:
            'Odśwież stan po zakolejkowanych wiadomościach przed edycją.',
      );
      return;
    }

    final details = ref.read(activeSessionDetailsViewProvider).valueOrNull;
    final sessionId = ref.read(selectedSessionProvider).sessionId;
    if (details == null || sessionId == null || sessionId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Nie udało się przygotować wiadomości do edycji.',
      );
      return;
    }

    SessionMessageItem? item;
    for (final candidate in details.items.whereType<SessionMessageItem>()) {
      if (candidate.id == itemId &&
          candidate.role == 'user' &&
          candidate.agentId == details.rootAgent.id) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      state = state.copyWith(
        errorMessage: 'Nie udało się przygotować wiadomości do edycji.',
      );
      return;
    }

    state = state.copyWith(
      editTarget: EditTarget(
        sessionId: sessionId,
        itemId: item.id,
        originalMessage: item.content,
        originalSequence: item.sequence,
        draft: item.content,
        attachments: item.attachments
            .map(PendingAttachment.fromSessionAttachment)
            .toList(growable: false),
      ),
      clearErrorMessage: true,
    );
  }

  Future<void> send({
    String? deliveryAgentId,
    String? deliveryCallId,
    String? rootAgentName,
  }) async {
    if (state.isSending || state.isStopping) {
      return;
    }
    if (state.isEditing) {
      state = state.copyWith(
        errorMessage:
            'Zapisz albo anuluj edycję wiadomości w historii przed wysłaniem nowej.',
      );
      return;
    }

    final trimmedDraft = state.draft.trim();
    if (trimmedDraft.isEmpty) {
      return;
    }

    state = state.copyWith(isSending: true, clearErrorMessage: true);
    final selection = ref.read(selectedSessionProvider);

    try {
      final repository = ref.read(chatRepositoryProvider);
      final shouldDeliver =
          deliveryAgentId != null &&
          deliveryAgentId.isNotEmpty &&
          deliveryCallId != null &&
          deliveryCallId.isNotEmpty;
      if (state.isStreaming && !shouldDeliver) {
        await _queuePendingMessage(
          repository: repository,
          sessionId: selection.sessionId,
          message: trimmedDraft,
          rootAgentName: rootAgentName,
        );
        return;
      }

      await _sendStreamMessage(
        repository: repository,
        message: trimmedDraft,
        sessionId: selection.sessionId,
        rootAgentName: rootAgentName,
        attachments: state.attachments,
        deliveryAgentId: shouldDeliver ? deliveryAgentId : null,
        deliveryCallId: shouldDeliver ? deliveryCallId : null,
      );
    } on ApiError catch (error) {
      debugPrint(
        '[composer.send.api_error] status_code=${error.statusCode ?? ''} message=${error.message}',
      );
      state = state.copyWith(isSending: false, errorMessage: error.message);
    } on StateError catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
    } catch (_) {
      debugPrint(
        '[composer.send.error] message=Nie udało się wysłać wiadomości.',
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Nie udało się wysłać wiadomości.',
      );
    }
  }

  Future<void> submitEdit({String? rootAgentName}) async {
    if (state.isSending || state.isStopping) {
      return;
    }

    final editTarget = state.editTarget;
    if (editTarget == null) {
      return;
    }

    final trimmedDraft = editTarget.draft.trim();
    if (trimmedDraft.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Treść wiadomości po edycji nie może być pusta.',
      );
      return;
    }

    state = state.copyWith(isSending: true, clearErrorMessage: true);

    try {
      final repository = ref.read(chatRepositoryProvider);
      await _editMessageStream(
        repository: repository,
        message: trimmedDraft,
        rootAgentName: rootAgentName,
      );
    } on ApiError catch (error) {
      debugPrint(
        '[composer.submit_edit.api_error] status_code=${error.statusCode ?? ''} message=${error.message}',
      );
      state = state.copyWith(isSending: false, errorMessage: error.message);
    } on StateError catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
    } catch (_) {
      debugPrint(
        '[composer.submit_edit.error] message=Nie udało się zapisać edycji wiadomości.',
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Nie udało się zapisać edycji wiadomości.',
      );
    }
  }

  Future<void> stop() async {
    final activeSessionId = state.activeSessionId;
    if (!state.canStop || activeSessionId == null || activeSessionId.isEmpty) {
      return;
    }

    state = state.copyWith(isStopping: true, clearErrorMessage: true);

    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.cancelRun(sessionId: activeSessionId);
    } on ApiError catch (error) {
      debugPrint(
        '[composer.stop.api_error] status_code=${error.statusCode ?? ''} message=${error.message}',
      );
      state = state.copyWith(isStopping: false, errorMessage: error.message);
    } catch (_) {
      debugPrint('[composer.stop.error] message=Nie udało się zatrzymać runu.');
      state = state.copyWith(
        isStopping: false,
        errorMessage: 'Nie udało się zatrzymać runu.',
      );
    }
  }

  Future<void> _queuePendingMessage({
    required ChatRepository repository,
    required String? sessionId,
    required String message,
    required String? rootAgentName,
  }) async {
    if (sessionId == null || sessionId.isEmpty) {
      throw const ApiError(
        message: 'Poczekaj na utworzenie sesji zanim dodasz kolejną wiadomość.',
      );
    }

    final queuedMessage = QueuedMessage(
      localId: 'local-queued-${DateTime.now().microsecondsSinceEpoch}',
      sessionId: sessionId,
      message: message,
      attachments: state.attachments,
      queuedAt: DateTime.now(),
    );
    final acknowledged = await repository.queueMessage(message: queuedMessage);
    final userContext = ref.read(userContextProvider);
    final resolvedAgent = _resolveRootAgentContext(
      sessionId: sessionId,
      fallbackRootAgentName: rootAgentName,
    );

    ref
        .read(sessionDetailsOverlayProvider.notifier)
        .queuePendingMessage(
          sessionId: sessionId,
          userId: userContext.userId,
          rootAgentId: resolvedAgent.id,
          rootAgentName: resolvedAgent.name,
          message: acknowledged,
        );
    final sessionEntry = _findSessionListEntry(sessionId);
    if (sessionEntry != null) {
      ref
          .read(sessionsListOverlayProvider.notifier)
          .upsert(
            sessionEntry.copyWith(
              lastMessagePreview: acknowledged.message,
              updatedAt: acknowledged.queuedAt,
            ),
          );
    }

    state = state.copyWith(
      draft: '',
      isSending: false,
      clearAttachments: true,
      pendingQueuedMessages: <QueuedMessage>[
        ...state.pendingQueuedMessages,
        acknowledged,
      ],
    );
  }

  Future<void> _editMessageStream({
    required ChatRepository repository,
    required String message,
    required String? rootAgentName,
  }) async {
    final editTarget = state.editTarget;
    if (editTarget == null) {
      throw const ApiError(message: 'Brak wiadomości do edycji.');
    }

    final startedAt = DateTime.now();
    final allAttachments = editTarget.attachments;
    final retainAttachmentIds = allAttachments
        .where((attachment) => attachment.isExisting)
        .map((attachment) => attachment.attachmentId!)
        .toList(growable: false);
    final attachments = allAttachments
        .where((attachment) => !attachment.isExisting)
        .toList(growable: false);
    final selectedDetails = ref
        .read(activeSessionDetailsViewProvider)
        .valueOrNull;
    final userContext = ref.read(userContextProvider);
    final resolvedAgent = _resolveRootAgentContext(
      sessionId: editTarget.sessionId,
      fallbackRootAgentName: rootAgentName,
    );

    ref
        .read(sessionDetailsOverlayProvider.notifier)
        .startEditRegeneration(
          sessionId: editTarget.sessionId,
          itemId: editTarget.itemId,
          userId: userContext.userId,
          rootAgentId: resolvedAgent.id,
          rootAgentName: resolvedAgent.name,
          message: message,
          attachments: _toSessionAttachments(allAttachments),
          startedAt: startedAt,
        );
    if (selectedDetails != null) {
      ref
          .read(sessionsListOverlayProvider.notifier)
          .syncStreamStart(
            sessionId: editTarget.sessionId,
            userId: userContext.userId,
            message: message,
            rootAgentId: resolvedAgent.id,
            rootAgentName: resolvedAgent.name,
            startedAt: startedAt,
          );
    }

    state = state
        .copyWith(clearActiveRun: true)
        .copyWith(
          draft: '',
          isSending: false,
          isStreaming: true,
          isStopping: false,
          pendingUserMessage: message,
          pendingUserAttachments: allAttachments,
          streamingText: '',
          activeSessionId: editTarget.sessionId,
          activeAgentId: resolvedAgent.id,
          activeAgentName: resolvedAgent.name,
          streamingStartedAt: startedAt,
          clearEditTarget: true,
          clearErrorMessage: true,
        );

    await _consumeStream(
      stream: repository.editMessageStream(
        sessionId: editTarget.sessionId,
        itemId: editTarget.itemId,
        message: message,
        retainAttachmentIds: retainAttachmentIds,
        attachments: attachments,
      ),
      message: message,
      rootAgentName: resolvedAgent.name,
      sessionId: editTarget.sessionId,
    );
  }

  Future<void> _sendStreamMessage({
    required ChatRepository repository,
    required String message,
    required String? sessionId,
    required String? rootAgentName,
    required List<PendingAttachment> attachments,
    String? deliveryAgentId,
    String? deliveryCallId,
  }) async {
    final startedAt = DateTime.now();
    state = state
        .copyWith(clearActiveRun: true)
        .copyWith(
          draft: '',
          isSending: false,
          isStreaming: true,
          isStopping: false,
          pendingUserMessage: message,
          pendingUserAttachments: attachments,
          streamingText: '',
          activeSessionId: sessionId,
          activeAgentName: rootAgentName,
          streamingStartedAt: startedAt,
          clearAttachments: true,
          clearEditTarget: true,
          clearErrorMessage: true,
        );

    final shouldDeliver =
        deliveryAgentId != null &&
        deliveryAgentId.isNotEmpty &&
        deliveryCallId != null &&
        deliveryCallId.isNotEmpty;
    if (sessionId != null && sessionId.isNotEmpty) {
      final userContext = ref.read(userContextProvider);
      final resolvedAgent = _resolveRootAgentContext(
        sessionId: sessionId,
        fallbackRootAgentName: rootAgentName,
      );
      ref
          .read(sessionsListOverlayProvider.notifier)
          .syncStreamStart(
            sessionId: sessionId,
            userId: userContext.userId,
            message: message,
            rootAgentId: resolvedAgent.id,
            rootAgentName: resolvedAgent.name,
            startedAt: startedAt,
          );
      ref
          .read(sessionDetailsOverlayProvider.notifier)
          .syncStreamStart(
            sessionId: sessionId,
            userId: userContext.userId,
            message: message,
            rootAgentId: resolvedAgent.id,
            rootAgentName: resolvedAgent.name,
            startedAt: startedAt,
            attachments: _toSessionAttachments(attachments),
          );
    }

    final stream = shouldDeliver
        ? repository.deliverMessageStream(
            agentId: deliveryAgentId,
            callId: deliveryCallId,
            message: message,
          )
        : repository.sendMessageStream(
            message: message,
            sessionId: sessionId,
            agentName: rootAgentName,
            attachments: attachments,
          );
    await _consumeStream(
      stream: stream,
      message: message,
      rootAgentName: rootAgentName,
      sessionId: sessionId,
    );
  }

  Future<void> _consumeStream({
    required Stream<ChatStreamEvent> stream,
    required String message,
    required String? rootAgentName,
    required String? sessionId,
  }) async {
    String? resolvedSessionId = sessionId;
    String? streamError;

    try {
      await for (final event in stream) {
        switch (event) {
          case ChatSessionStartedStreamEvent(:final sessionId, :final agentId):
            final shouldCreateLocalStreamState =
                state.activeSessionId != sessionId;
            resolvedSessionId = sessionId;
            if (shouldCreateLocalStreamState) {
              final userContext = ref.read(userContextProvider);
              final agentName =
                  state.activeAgentName ?? rootAgentName ?? 'Manfred';
              ref
                  .read(sessionsListOverlayProvider.notifier)
                  .syncStreamStart(
                    sessionId: sessionId,
                    userId: userContext.userId,
                    message: message,
                    rootAgentId: agentId,
                    rootAgentName: agentName,
                    startedAt: state.streamingStartedAt ?? DateTime.now(),
                  );
              ref
                  .read(sessionDetailsOverlayProvider.notifier)
                  .syncStreamStart(
                    sessionId: sessionId,
                    userId: userContext.userId,
                    message: message,
                    rootAgentId: agentId,
                    rootAgentName: agentName,
                    startedAt: state.streamingStartedAt ?? DateTime.now(),
                    attachments: _toSessionAttachments(
                      state.pendingUserAttachments,
                    ),
                  );
            }
            ref.read(selectedSessionProvider.notifier).select(sessionId);
            state = state.copyWith(
              activeSessionId: sessionId,
              activeAgentId: agentId,
            );
          case ChatTextDeltaStreamEvent(:final delta):
            state = state.copyWith(
              streamingText: '${state.streamingText}$delta',
            );
            if (resolvedSessionId != null && resolvedSessionId.isNotEmpty) {
              ref
                  .read(sessionDetailsOverlayProvider.notifier)
                  .appendStreamingText(
                    sessionId: resolvedSessionId,
                    delta: delta,
                    updatedAt: DateTime.now(),
                  );
            }
          case ChatTextDoneStreamEvent(:final text):
            state = state.copyWith(streamingText: text);
            if (resolvedSessionId != null && resolvedSessionId.isNotEmpty) {
              ref
                  .read(sessionDetailsOverlayProvider.notifier)
                  .setStreamingText(
                    sessionId: resolvedSessionId,
                    text: text,
                    updatedAt: DateTime.now(),
                  );
            }
          case ChatFunctionCallDeltaStreamEvent():
            break;
          case ChatFunctionCallDoneStreamEvent(
            :final callId,
            :final name,
            :final arguments,
          ):
            if (resolvedSessionId != null && resolvedSessionId.isNotEmpty) {
              ref
                  .read(sessionDetailsOverlayProvider.notifier)
                  .upsertToolCall(
                    sessionId: resolvedSessionId,
                    callId: callId,
                    name: name,
                    arguments: arguments,
                    updatedAt: DateTime.now(),
                  );
            }
          case ChatErrorStreamEvent(:final error):
            if (!state.isStopping) {
              streamError = error;
            }
          case ChatDoneStreamEvent():
            break;
        }
      }
    } on ApiError catch (error) {
      debugPrint(
        '[composer.stream.api_error] status_code=${error.statusCode ?? ''} message=${error.message}',
      );
      if (!state.isStopping) {
        streamError = error.message;
      }
    } catch (_) {
      debugPrint(
        '[composer.stream.error] message=Nie udało się streamować odpowiedzi.',
      );
      if (!state.isStopping) {
        streamError = 'Nie udało się streamować odpowiedzi.';
      }
    }

    final requiresSyncFallback = state.isStopping || streamError != null;
    if (resolvedSessionId != null && resolvedSessionId.isNotEmpty) {
      final finishedAt = DateTime.now();
      final finalRootAgentStatus = switch ((state.isStopping, streamError)) {
        (true, _) => 'cancelled',
        (false, String _) => 'failed',
        _ => 'completed',
      };
      ref
          .read(sessionDetailsOverlayProvider.notifier)
          .syncStreamDone(
            sessionId: resolvedSessionId,
            finishedAt: finishedAt,
            rootAgentStatus: finalRootAgentStatus,
          );
      ref
          .read(sessionsListOverlayProvider.notifier)
          .syncStreamDone(
            sessionId: resolvedSessionId,
            finishedAt: finishedAt,
            rootAgentStatus: finalRootAgentStatus,
            finalPreview: state.streamingText.isNotEmpty
                ? state.streamingText
                : message,
          );
      if (!requiresSyncFallback) {
        await _syncCanonicalSessionState(sessionId: resolvedSessionId);
      }
    }

    await _reconcileAfterStream(
      sessionId: resolvedSessionId,
      requiresSyncFallback: requiresSyncFallback,
    );
    final finalErrorMessage = streamError ?? state.errorMessage;
    state = state.copyWith(
      isSending: false,
      isStreaming: false,
      isStopping: false,
      clearPendingUserMessage: true,
      clearPendingUserAttachments: true,
      clearStreamingText: true,
      clearActiveRun: true,
      clearEditTarget: true,
      errorMessage: finalErrorMessage,
      clearErrorMessage: finalErrorMessage == null,
    );
  }

  Future<void> _reconcileAfterStream({
    required String? sessionId,
    required bool requiresSyncFallback,
  }) async {
    if (sessionId == null || sessionId.isEmpty) {
      if (requiresSyncFallback) {
        ref.invalidate(sessionsListProvider);
        ref.invalidate(sessionDetailsProvider);
      }
      return;
    }

    if (!requiresSyncFallback) {
      return;
    }

    ref.read(selectedSessionProvider.notifier).select(sessionId);
    ref.read(sessionDetailsOverlayProvider.notifier).remove(sessionId);
    ref.read(sessionsListOverlayProvider.notifier).remove(sessionId);
    ref.invalidate(sessionsListProvider);
    ref.invalidate(sessionDetailsProvider);
  }

  SessionListEntry? _findSessionListEntry(String sessionId) {
    final sessions = ref.read(sessionsListViewProvider).valueOrNull;
    if (sessions == null) {
      return null;
    }

    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }

    return null;
  }

  Future<void> _syncCanonicalSessionState({required String sessionId}) async {
    try {
      final userContext = ref.read(userContextProvider);
      final repository = ref.read(sessionsRepositoryProvider);
      final results = await Future.wait<Object?>(<Future<Object?>>[
        repository.fetchSessionDetails(userContext.userId, sessionId),
        repository.fetchSessions(userContext.userId),
      ]);
      final details = results[0] as SessionDetails;
      final sessions = results[1] as List<SessionListEntry>;
      final sessionEntry = _findSessionInList(sessions, sessionId);
      final mergedDetails = sessionEntry == null
          ? details
          : details.copyWith(
              session: details.session.copyWith(
                title: sessionEntry.title,
                status: sessionEntry.status,
                createdAt: sessionEntry.createdAt,
                updatedAt: sessionEntry.updatedAt,
              ),
              rootAgent: details.rootAgent.copyWith(
                id: sessionEntry.rootAgentId,
                name: sessionEntry.rootAgentName,
                status: sessionEntry.rootAgentStatus,
              ),
            );

      ref.read(sessionDetailsOverlayProvider.notifier).replace(mergedDetails);
      final unresolvedQueued = _findUnresolvedQueuedMessages(
        sessionId: sessionId,
        details: mergedDetails,
      );
      for (final queuedMessage in unresolvedQueued) {
        ref
            .read(sessionDetailsOverlayProvider.notifier)
            .queuePendingMessage(
              sessionId: sessionId,
              userId: userContext.userId,
              rootAgentId: mergedDetails.rootAgent.id,
              rootAgentName: mergedDetails.rootAgent.name,
              message: queuedMessage,
            );
      }

      final otherQueuedMessages = state.pendingQueuedMessages
          .where((item) => item.sessionId != sessionId)
          .toList(growable: false);
      state = state.copyWith(
        pendingQueuedMessages: <QueuedMessage>[
          ...otherQueuedMessages,
          ...unresolvedQueued,
        ],
      );

      if (sessionEntry != null) {
        ref
            .read(sessionsListOverlayProvider.notifier)
            .upsert(
              unresolvedQueued.isEmpty
                  ? sessionEntry
                  : sessionEntry.copyWith(
                      lastMessagePreview: unresolvedQueued.last.message,
                      updatedAt: unresolvedQueued.last.queuedAt,
                    ),
            );
      }
    } catch (_) {
      debugPrint(
        '[composer.stream.sync.error] message=Nie udało się zsynchronizować danych sesji po streamie.',
      );
    }
  }

  List<QueuedMessage> _findUnresolvedQueuedMessages({
    required String sessionId,
    required SessionDetails details,
  }) {
    final queuedMessages = state.pendingQueuedMessages
        .where((item) => item.sessionId == sessionId)
        .toList(growable: false);
    if (queuedMessages.isEmpty) {
      return const <QueuedMessage>[];
    }

    final canonicalMessages = details.items
        .whereType<SessionMessageItem>()
        .where(
          (item) => item.role == 'user' && item.agentId == details.rootAgent.id,
        )
        .toList(growable: false);
    final matchedIds = <String>{};
    final unresolved = <QueuedMessage>[];

    for (final queuedMessage in queuedMessages) {
      final matchedItem = canonicalMessages
          .cast<SessionMessageItem?>()
          .firstWhere(
            (item) =>
                item != null &&
                !matchedIds.contains(item.id) &&
                item.content == queuedMessage.message &&
                _attachmentsMatch(item.attachments, queuedMessage.attachments),
            orElse: () => null,
          );
      if (matchedItem == null) {
        unresolved.add(queuedMessage);
        continue;
      }
      matchedIds.add(matchedItem.id);
    }

    return unresolved;
  }

  bool _attachmentsMatch(
    List<SessionAttachment> canonical,
    List<PendingAttachment> pending,
  ) {
    if (canonical.length != pending.length) {
      return false;
    }

    final counts = <String, int>{};
    for (final a in canonical) {
      final key = '${a.fileName}:${a.sizeBytes}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final a in pending) {
      final key = '${a.fileName}:${a.sizeBytes}';
      final remaining = counts[key];
      if (remaining == null || remaining == 0) {
        return false;
      }
      counts[key] = remaining - 1;
    }

    return true;
  }

  _ResolvedRootAgent _resolveRootAgentContext({
    required String sessionId,
    required String? fallbackRootAgentName,
  }) {
    final selectedDetails = ref
        .read(activeSessionDetailsViewProvider)
        .valueOrNull;
    final selectedSession = _findSessionListEntry(sessionId);
    final resolvedAgentId =
        selectedDetails?.rootAgent.id ?? selectedSession?.rootAgentId;
    if (resolvedAgentId == null || resolvedAgentId.isEmpty) {
      throw const ApiError(
        message: 'Nie udało się ustalić root agenta aktywnej sesji.',
      );
    }

    return _ResolvedRootAgent(
      id: resolvedAgentId,
      name:
          fallbackRootAgentName ??
          selectedDetails?.rootAgent.name ??
          selectedSession?.rootAgentName ??
          'Manfred',
    );
  }

  List<SessionAttachment> _toSessionAttachments(
    List<PendingAttachment> attachments,
  ) {
    return attachments
        .map((attachment) => attachment.toSessionAttachment())
        .toList(growable: false);
  }

  SessionListEntry? _findSessionInList(
    List<SessionListEntry> sessions,
    String sessionId,
  ) {
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }

    return null;
  }
}

class _ResolvedRootAgent {
  const _ResolvedRootAgent({required this.id, required this.name});

  final String id;
  final String name;
}

final composerControllerProvider =
    NotifierProvider<ComposerController, ComposerState>(ComposerController.new);
