import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/application/user_context_provider.dart';
import '../data/sessions_repository.dart';
import '../domain/session_details.dart';
import 'selected_session_provider.dart';

final sessionDetailsProvider = FutureProvider<SessionDetails?>((ref) async {
  final selection = ref.watch(selectedSessionProvider);
  if (selection.sessionId == null) {
    return null;
  }

  final repository = ref.watch(sessionsRepositoryProvider);
  final userContext = ref.watch(userContextProvider);
  return repository.fetchSessionDetails(
    userContext.userId,
    selection.sessionId!,
  );
});
