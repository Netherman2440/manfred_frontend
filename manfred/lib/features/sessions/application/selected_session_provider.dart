import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedSessionState {
  const SelectedSessionState({required this.sessionId, required this.isDraft});

  const SelectedSessionState.initial() : sessionId = null, isDraft = false;

  final String? sessionId;
  final bool isDraft;

  bool get hasActiveSession => sessionId != null;
}

class SelectedSessionController extends Notifier<SelectedSessionState> {
  @override
  SelectedSessionState build() => const SelectedSessionState.initial();

  void select(String sessionId) {
    if (state.sessionId == sessionId && !state.isDraft) {
      return;
    }
    state = SelectedSessionState(sessionId: sessionId, isDraft: false);
  }

  void startDraft() {
    state = const SelectedSessionState(sessionId: null, isDraft: true);
  }

  void clear() {
    state = const SelectedSessionState.initial();
  }
}

final selectedSessionProvider =
    NotifierProvider<SelectedSessionController, SelectedSessionState>(
      SelectedSessionController.new,
    );
