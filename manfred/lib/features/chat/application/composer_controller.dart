import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../sessions/application/session_details_provider.dart';
import '../../sessions/application/sessions_list_provider.dart';
import '../../sessions/application/selected_session_provider.dart';
import '../data/chat_repository.dart';
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

  Future<void> send({String? deliveryAgentId, String? deliveryCallId}) async {
    if (state.isSending) {
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
}

final composerControllerProvider =
    NotifierProvider<ComposerController, ComposerState>(ComposerController.new);
