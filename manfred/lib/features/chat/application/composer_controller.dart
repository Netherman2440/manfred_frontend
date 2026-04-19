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

  Future<void> send() async {
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
      final result = await ref
          .read(chatRepositoryProvider)
          .sendMessage(message: trimmedDraft, sessionId: selection.sessionId);

      if (result.sessionId.isEmpty) {
        throw StateError('Backend did not return session_id.');
      }

      ref.read(selectedSessionProvider.notifier).select(result.sessionId);
      ref.invalidate(sessionsListProvider);
      ref.invalidate(sessionDetailsProvider);
      state = const ComposerState.initial();
    } on ApiError catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
        clearErrorMessage: false,
      );
    } catch (_) {
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
