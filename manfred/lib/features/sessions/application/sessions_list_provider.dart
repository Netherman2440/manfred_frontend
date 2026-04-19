import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/application/user_context_provider.dart';
import '../data/sessions_repository.dart';
import '../domain/session_list_entry.dart';

final sessionsListProvider = FutureProvider<List<SessionListEntry>>((
  ref,
) async {
  final repository = ref.watch(sessionsRepositoryProvider);
  final userContext = ref.watch(userContextProvider);
  return repository.fetchSessions(userContext.userId);
});
