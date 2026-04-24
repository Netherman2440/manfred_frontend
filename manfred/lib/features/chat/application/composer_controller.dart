import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../sessions/application/session_details_provider.dart';
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
      final result = shouldDeliver
          ? await repository.deliverMessage(
              agentId: deliveryAgentId,
              callId: deliveryCallId,
              message: trimmedDraft,
            )
          : await repository.sendMessage(
              message: trimmedDraft,
              sessionId: selection.sessionId,
            );

      if (result.sessionId.isEmpty) {
        throw StateError('Backend did not return session_id.');
      }

      debugPrint(
        '[composer.send.result] mode=${shouldDeliver ? 'deliver' : 'chat'} session_id=${result.sessionId} agent_id=${result.agentId} status=${result.status} error=${result.error ?? ''}',
      );

      ref.read(selectedSessionProvider.notifier).select(result.sessionId);
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
    state = state.copyWith(
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
    try {
      await for (final event in repository.sendMessageStream(
        message: message,
        sessionId: sessionId,
      )) {
        switch (event) {
          case ChatSessionStartedStreamEvent(:final sessionId, :final agentId):
            resolvedSessionId = sessionId;
            ref.read(selectedSessionProvider.notifier).select(sessionId);
            ref.invalidate(sessionsListProvider);
            ref.invalidate(sessionDetailsProvider);
            state = state.copyWith(
              activeSessionId: sessionId,
              activeAgentId: agentId,
            );
          case ChatTextDeltaStreamEvent(:final delta):
            state = state.copyWith(
              streamingText: '${state.streamingText}$delta',
            );
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
      streamError = error.message;
    } catch (_) {
      debugPrint(
        '[composer.stream.error] message=Nie udało się streamować odpowiedzi.',
      );
      if (!state.isStopping) {
        streamError = 'Nie udało się streamować odpowiedzi.';
      }
    }

    await _reconcileAfterStream(sessionId: resolvedSessionId);
    state = const ComposerState.initial().copyWith(
      errorMessage: streamError,
      clearErrorMessage: streamError == null,
    );
  }

  Future<void> _reconcileAfterStream({required String? sessionId}) async {
    if (sessionId == null || sessionId.isEmpty) {
      ref.invalidate(sessionsListProvider);
      ref.invalidate(sessionDetailsProvider);
      return;
    }

    final selectionController = ref.read(selectedSessionProvider.notifier);
    selectionController.select(sessionId);
    ref.invalidate(sessionsListProvider);
    ref.invalidate(sessionDetailsProvider);

    try {
      final userContext = ref.read(userContextProvider);
      final sessionsRepository = ref.read(sessionsRepositoryProvider);
      final sessions = await sessionsRepository.fetchSessions(
        userContext.userId,
      );
      final resolvedSessionId = _resolveSessionSelection(
        requestedSessionId: sessionId,
        sessions: sessions,
      );
      if (resolvedSessionId != null) {
        selectionController.select(resolvedSessionId);
      }
    } catch (_) {
      debugPrint(
        '[composer.stream.reconcile.error] message=Nie udało się odświeżyć listy sesji po streamie.',
      );
    } finally {
      ref.invalidate(sessionsListProvider);
      ref.invalidate(sessionDetailsProvider);
    }
  }

  String? _resolveSessionSelection({
    required String requestedSessionId,
    required List<SessionListEntry> sessions,
  }) {
    for (final session in sessions) {
      if (session.id == requestedSessionId) {
        return requestedSessionId;
      }
    }

    if (sessions.isEmpty) {
      return null;
    }

    return sessions.first.id;
  }
}

final composerControllerProvider =
    NotifierProvider<ComposerController, ComposerState>(ComposerController.new);
