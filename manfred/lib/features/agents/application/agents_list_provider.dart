import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agents_repository.dart';
import '../domain/agent_summary.dart';

class AgentsListNotifier extends AsyncNotifier<List<AgentSummary>> {
  @override
  Future<List<AgentSummary>> build() {
    return ref.read(agentsRepositoryProvider).listAgents();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(agentsRepositoryProvider).listAgents(),
    );
  }
}

final agentsListProvider =
    AsyncNotifierProvider<AgentsListNotifier, List<AgentSummary>>(
  AgentsListNotifier.new,
);
