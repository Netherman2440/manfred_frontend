import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/agents/application/agent_editor_provider.dart';
import '../../../../features/agents/application/agents_list_provider.dart';
import '../../../../features/agents/application/selected_agent_provider.dart';
import '../../../../features/agents/data/agents_repository.dart';
import '../../../../features/agents/domain/agent_editor_target.dart';
import '../../../../features/agents/domain/agent_summary.dart';
import '../../../../features/chat/application/composer_controller.dart';
import '../../../../features/sessions/application/selected_session_provider.dart';
import '../../../core/agent_avatar.dart';
import '../../../core/hover_tile_container.dart';
import '../../../theme/manfred_theme.dart';

class AgentColumn extends ConsumerWidget {
  const AgentColumn({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsListProvider);
    final selectedAgentName = ref.watch(selectedAgentNameProvider);

    return agentsAsync.when(
      loading: () => compact
          ? _CompactAgentColumnSkeleton()
          : _DesktopAgentColumnSkeleton(),
      error: (error, _) => _AgentColumnError(
        onRetry: () => ref.read(agentsListProvider.notifier).refresh(),
      ),
      data: (agents) => compact
          ? _CompactAgentColumn(
              agents: agents,
              selectedAgentName: selectedAgentName,
              onAgentTap: (agent) => _onAgentTap(context, ref, agent),
              onAddAgent: () => _onAddAgent(context, ref),
            )
          : _DesktopAgentColumn(
              agents: agents,
              selectedAgentName: selectedAgentName,
              onAgentTap: (agent) => _onAgentTap(context, ref, agent),
              onAddAgent: () => _onAddAgent(context, ref),
            ),
    );
  }

  /// Returns `true` when the workspace is free to navigate away from the
  /// current editor (no dirty state, or user accepted to discard).
  Future<bool> _confirmDiscardIfDirty(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final workspaceMode = ref.read(workspaceModeProvider);
    if (workspaceMode != WorkspaceMode.agentEditor) return true;
    if (!ref.read(agentEditorIsDirtyProvider)) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ManfredColors.panelAltBackground,
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _onAgentTap(
    BuildContext context,
    WidgetRef ref,
    AgentSummary agent,
  ) async {
    if (!await _confirmDiscardIfDirty(context, ref)) return;
    if (!context.mounted) return;
    if (ref.read(workspaceModeProvider) == WorkspaceMode.agentEditor) {
      ref.read(workspaceModeProvider.notifier).state =
          WorkspaceMode.conversation;
    }

    ref.read(selectedAgentNameProvider.notifier).state = agent.name;
    // Reset session immediately so the main panel shows the new agent's context
    ref.read(selectedSessionProvider.notifier).startDraft();
    ref.read(composerControllerProvider.notifier).resetDraft();

    try {
      final requestedAgentName = agent.name;
      final sessions = await ref
          .read(agentsRepositoryProvider)
          .getAgentSessions(requestedAgentName);
      // Drop stale responses if the user switched agents while we were
      // waiting for /sessions to return.
      if (ref.read(selectedAgentNameProvider) != requestedAgentName) return;
      if (sessions.isNotEmpty) {
        ref.read(selectedSessionProvider.notifier).select(sessions.first.id);
      }
    } catch (_) {
      // No sessions or network error — composer stays in draft state
    }
  }

  Future<void> _onAddAgent(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDiscardIfDirty(context, ref)) return;
    if (!context.mounted) return;
    ref.read(agentEditorTargetProvider.notifier).state =
        const AgentEditorTarget.create();
    ref.read(workspaceModeProvider.notifier).state = WorkspaceMode.agentEditor;
  }
}

// ---------------------------------------------------------------------------
// Desktop layout
// ---------------------------------------------------------------------------

class _DesktopAgentColumn extends StatelessWidget {
  const _DesktopAgentColumn({
    required this.agents,
    required this.selectedAgentName,
    required this.onAgentTap,
    required this.onAddAgent,
  });

  final List<AgentSummary> agents;
  final String selectedAgentName;
  final ValueChanged<AgentSummary> onAgentTap;
  final VoidCallback onAddAgent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              itemCount: agents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agent = agents[index];
                return Tooltip(
                  message: agent.name,
                  child: _AgentRailItem(
                    agent: agent,
                    isActive: agent.name == selectedAgentName,
                    onTap: () => onAgentTap(agent),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _AddAgentButton(onTap: onAddAgent),
          // Extra space so the button clears the floating WorkspaceAccountBar
          // (72 px height + 20 px bottom offset + buffer).
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact layout
// ---------------------------------------------------------------------------

class _CompactAgentColumn extends StatelessWidget {
  const _CompactAgentColumn({
    required this.agents,
    required this.selectedAgentName,
    required this.onAgentTap,
    required this.onAddAgent,
  });

  final List<AgentSummary> agents;
  final String selectedAgentName;
  final ValueChanged<AgentSummary> onAgentTap;
  final VoidCallback onAddAgent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Agents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                ...agents.map(
                  (agent) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Semantics(
                      button: true,
                      selected: agent.name == selectedAgentName,
                      label: agent.name,
                      child: GestureDetector(
                        onTap: () => onAgentTap(agent),
                        child: HoverTileContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isActive: agent.name == selectedAgentName,
                          baseColor: ManfredColors.panelAltBackground,
                          child: Row(
                            children: <Widget>[
                              AgentAvatar(
                                label: _avatarLabel(agent.name),
                                accentColor: agent.color,
                                size: 34,
                                isActive: agent.name == selectedAgentName,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                agent.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: agent.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _AddAgentButton(onTap: onAddAgent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rail item
// ---------------------------------------------------------------------------

class _AgentRailItem extends StatefulWidget {
  const _AgentRailItem({
    required this.agent,
    required this.isActive,
    required this.onTap,
  });

  final AgentSummary agent;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_AgentRailItem> createState() => _AgentRailItemState();
}

class _AgentRailItemState extends State<_AgentRailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accentColor = widget.agent.color ?? ManfredColors.accentBlue;
    final markerColor = widget.isActive
        ? accentColor
        : (_isHovered ? ManfredColors.borderStrong : Colors.transparent);
    final markerHeight = widget.isActive ? 44.0 : (_isHovered ? 18.0 : 0.0);
    final markerTop = widget.isActive ? 5.0 : 18.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        button: true,
        selected: widget.isActive,
        label: widget.agent.name,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                left: 0,
                top: markerTop,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  width: 4,
                  height: markerHeight,
                  decoration: BoxDecoration(
                    color: markerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AgentAvatar(
                        label: _avatarLabel(widget.agent.name),
                        accentColor: accentColor,
                        size: 54,
                        isActive: widget.isActive,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.agent.name,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add agent button
// ---------------------------------------------------------------------------

class _AddAgentButton extends StatelessWidget {
  const _AddAgentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nowy agent',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: _PlusAvatar(),
      ),
    );
  }
}

class _PlusAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ManfredColors.panelAltBackground,
        border: Border.all(
          color: ManfredColors.borderStrong,
          style: BorderStyle.solid,
        ),
      ),
      child: const Icon(
        Icons.add,
        color: ManfredColors.textSecondary,
        size: 20,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeletons
// ---------------------------------------------------------------------------

class _DesktopAgentColumnSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            SizedBox(height: i > 0 ? 12 : 0),
            _SkeletonCircle(size: 54),
          ],
          const Spacer(),
          _AddAgentButton(onTap: () {}),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _CompactAgentColumnSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Agents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 10),
                _SkeletonCircle(size: 34),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ManfredColors.panelAltBackground,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _AgentColumnError extends StatelessWidget {
  const _AgentColumnError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline, color: ManfredColors.accentRed),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

String _avatarLabel(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  // Take first two meaningful chars: split by non-alphanumeric, take first
  // char of each segment (max 2).
  final segments = trimmed.split(RegExp(r'[^a-zA-Z0-9]'));
  final chars = segments.where((s) => s.isNotEmpty).map((s) => s[0]).toList();
  if (chars.length >= 2) {
    return '${chars[0]}${chars[1]}'.toUpperCase();
  }
  if (trimmed.length >= 2) {
    return trimmed.substring(0, 2).toUpperCase();
  }
  return trimmed[0].toUpperCase();
}
