import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agents_repository.dart';
import '../domain/agent_detail.dart';
import '../domain/agent_editor_target.dart';

enum WorkspaceMode {
  conversation,
  agentEditor,
}

final workspaceModeProvider = StateProvider<WorkspaceMode>(
  (ref) => WorkspaceMode.conversation,
);

final agentEditorTargetProvider = StateProvider<AgentEditorTarget?>(
  (ref) => null,
);

final agentEditorIsDirtyProvider = StateProvider<bool>((ref) => false);

/// Per-name lookup used by chat items (e.g. AgentMessageItem).
/// Riverpod caches per key.
final agentDetailByNameProvider =
    FutureProvider.family<AgentDetail?, String>((ref, name) async {
  try {
    return await ref.watch(agentsRepositoryProvider).getAgent(name);
  } on AgentNotFound {
    return null;
  }
});
