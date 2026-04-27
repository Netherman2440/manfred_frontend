import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../sessions/application/session_details_provider.dart';
import '../../sessions/application/session_overlay_providers.dart';
import '../../sessions/application/sessions_list_provider.dart';
import '../../sessions/application/selected_session_provider.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../sessions/domain/session_list_entry.dart';
import '../../user/application/user_context_provider.dart';
import '../data/chat_repository.dart';
import '../domain/chat_stream_event.dart';
import '../domain/composer_state.dart';

class ComposerController extends Notifier<ComposerState> {
  @override
  ComposerState build() => const ComposerState.initial();

  void updateDraft(String value) {
    state = state.copyWith(draft: value, clearErrorMessage: true);
  }

  void resetDraft() {
    state = const ComposerState.initial();
  }

  Future<void> send({
    String? deliveryAgentId,
    String? deliveryCallId,
    String? rootAgentName,
  }) async {
    if (state.isBusy) {
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
      if (shouldDeliver) {
        debugPrint(
          '[composer.send] mode=deliver agent_id=$deliveryAgentId call_id=$deliveryCallId session_id=${selection.sessionId ?? ''}',
        );
      } else {
        debugPrint(
          '[composer.send] mode=chat session_id=${selection.sessionId ?? ''}',
        );
      }
      if (!shouldDeliver) {
        await _sendStreamMessage(
          repository: repository,
          message: trimmedDraft,
          sessionId: selection.sessionId,
          rootAgentName: rootAgentName,
        );
        return;
      }
      final result = await repository.deliverMessage(
        agentId: deliveryAgentId,
        callId: deliveryCallId,
        message: trimmedDraft,
      );

      if (result.sessionId.isEmpty) {
        throw StateError('Backend did not return session_id.');
      }

      debugPrint(
        '[composer.send.result] mode=deliver session_id=${result.sessionId} agent_id=${result.agentId} status=${result.status} error=${result.error ?? ''}',
      );

      ref.read(selectedSessionProvider.notifier).select(result.sessionId);
      ref.read(sessionsListOverlayProvider.notifier).remove(result.sessionId);
      ref.read(sessionDetailsOverlayProvider.notifier).remove(result.sessionId);
      ref.invalidate(sessionsListProvider);
      ref.invalidate(sessionDetailsProvider);
      debugPrint(
        '[composer.send.invalidate] sessions_list=true session_details=true selected_session=${result.sessionId}',
      );
      state = const ComposerState.initial();
    } on ApiError catch (error) {
      debugPrint(
        '[composer.send.api_error] status_code=${error.statusCode ?? ''} message=${error.message}',
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
        clearErrorMessage: false,
      );
    } catch (_) {
      debugPrint(
        '[composer.send.error] message=Nie udało się wysłać wiadomości.',
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Nie udało się wysłać wiadomości.',
        clearErrorMessage: false,
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
      state = state.copyWith(
        isStopping: false,
        errorMessage: error.message,
        clearErrorMessage: false,
      );
    } catch (_) {
      debugPrint('[composer.stop.error] message=Nie udało się zatrzymać runu.');
      state = state.copyWith(
        isStopping: false,
        errorMessage: 'Nie udało się zatrzymać runu.',
        clearErrorMessage: false,
      );
    }
  }

  Future<void> _sendStreamMessage({
    required ChatRepository repository,
    required String message,
    required String? sessionId,
    required String? rootAgentName,
  }) async {
    state = state
        .copyWith(clearActiveRun: true)
        .copyWith(
          draft: '',
          isSending: false,
          isStreaming: true,
          isStopping: false,
          pendingUserMessage: message,
          streamingText: '',
          activeSessionId: sessionId,
          activeAgentName: rootAgentName,
          clearErrorMessage: true,
        );

    String? resolvedSessionId = sessionId;
    String? streamError;
    if (sessionId != null && sessionId.isNotEmpty) {
      final selectedDetails = ref
          .read(activeSessionDetailsViewProvider)
          .valueOrNull;
      final selectedSession = _findSessionListEntry(sessionId);
      final resolvedAgentId =
          selectedDetails?.rootAgent.id ?? selectedSession?.rootAgentId;
      final resolvedAgentName =
          rootAgentName ??
          selectedDetails?.rootAgent.name ??
          selectedSession?.rootAgentName ??
          'Manfred';
      if (resolvedAgentId != null && resolvedAgentId.isNotEmpty) {
        final now = DateTime.now();
        final userContext = ref.read(userContextProvider);
        ref
            .read(sessionsListOverlayProvider.notifier)
            .syncStreamStart(
              sessionId: sessionId,
              userId: userContext.userId,
              message: message,
              rootAgentId: resolvedAgentId,
              rootAgentName: resolvedAgentName,
              startedAt: now,
            );
        ref
            .read(sessionDetailsOverlayProvider.notifier)
            .syncStreamStart(
              sessionId: sessionId,
              userId: userContext.userId,
              message: message,
              rootAgentId: resolvedAgentId,
              rootAgentName: resolvedAgentName,
              startedAt: now,
            );
      }
    }
    try {
      await for (final event in repository.sendMessageStream(
        message: message,
        sessionId: sessionId,
      )) {
        switch (event) {
          case ChatSessionStartedStreamEvent(:final sessionId, :final agentId):
            final shouldCreateLocalStreamState =
                state.activeSessionId != sessionId;
            resolvedSessionId = sessionId;
            if (shouldCreateLocalStreamState) {
              final now = DateTime.now();
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
                    startedAt: now,
                  );
              ref
                  .read(sessionDetailsOverlayProvider.notifier)
                  .syncStreamStart(
                    sessionId: sessionId,
                    userId: userContext.userId,
                    message: message,
                    rootAgentId: agentId,
                    rootAgentName: agentName,
                    startedAt: now,
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

    if (resolvedSessionId != null && resolvedSessionId.isNotEmpty) {
      final finishedAt = DateTime.now();
      ref
          .read(sessionDetailsOverlayProvider.notifier)
          .syncStreamDone(sessionId: resolvedSessionId, finishedAt: finishedAt);
      ref
          .read(sessionsListOverlayProvider.notifier)
          .syncStreamDone(
            sessionId: resolvedSessionId,
            finishedAt: finishedAt,
            finalPreview: state.streamingText.isNotEmpty
                ? state.streamingText
                : message,
          );
      await _syncCanonicalSessionState(sessionId: resolvedSessionId);
    }

    final requiresSyncFallback = state.isStopping || streamError != null;
    await _reconcileAfterStream(
      sessionId: resolvedSessionId,
      requiresSyncFallback: requiresSyncFallback,
    );
    final finalErrorMessage = streamError ?? state.errorMessage;
    state = const ComposerState.initial().copyWith(
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
      final details = await repository.fetchSessionDetails(
        userContext.userId,
        sessionId,
      );
      ref.read(sessionDetailsOverlayProvider.notifier).replace(details);

      final sessions = await repository.fetchSessions(userContext.userId);
      final sessionEntry = _findSessionInList(sessions, sessionId);
      if (sessionEntry != null) {
        ref.read(sessionsListOverlayProvider.notifier).upsert(sessionEntry);
        ref
            .read(sessionDetailsOverlayProvider.notifier)
            .replace(
              details.copyWith(
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
              ),
            );
      }
    } catch (_) {
      debugPrint(
        '[composer.stream.sync.error] message=Nie udało się zsynchronizować danych sesji po streamie.',
      );
    }
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

final composerControllerProvider =
    NotifierProvider<ComposerController, ComposerState>(ComposerController.new);
