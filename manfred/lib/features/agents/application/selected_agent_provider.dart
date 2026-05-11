import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agents_repository.dart';
import '../domain/agent_detail.dart';

// Default agent name — must match backend DEFAULT_AGENT env (currently "manfred").
const String kDefaultAgentName = 'manfred';

/// Always non-null. Invariant: there is always a selected agent.
/// Starts as kDefaultAgentName at app launch.
final selectedAgentNameProvider = StateProvider<String>(
  (ref) => kDefaultAgentName,
);

/// Detail of the currently-selected agent. Auto-disposes when no longer watched.
final selectedAgentDetailProvider =
    FutureProvider.autoDispose<AgentDetail>((ref) async {
  final name = ref.watch(selectedAgentNameProvider);
  return ref.watch(agentsRepositoryProvider).getAgent(name);
});
