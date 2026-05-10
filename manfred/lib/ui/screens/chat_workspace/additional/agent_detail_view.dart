import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/agents/application/agent_editor_provider.dart';
import '../../../../features/agents/application/agents_list_provider.dart';
import '../../../../features/agents/application/selected_agent_provider.dart';
import '../../../../features/agents/data/agents_repository.dart';
import '../../../../features/agents/domain/agent_detail.dart';
import '../../../../features/agents/domain/agent_editor_target.dart';
import '../../../../features/sessions/domain/session_list_entry.dart';
import '../../../core/agent_avatar.dart';
import '../../../theme/manfred_theme.dart';

class AgentDetailView extends ConsumerWidget {
  const AgentDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(selectedAgentDetailProvider);

    return detailAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(
        child: Text('Failed to load agent details'),
      ),
      data: (detail) => _AgentDetailContent(detail: detail),
    );
  }
}

class _AgentDetailContent extends ConsumerWidget {
  const _AgentDetailContent({required this.detail});

  final AgentDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with edit/delete buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit agent',
                iconSize: 18,
                onPressed: () {
                  ref.read(agentEditorTargetProvider.notifier).state =
                      AgentEditorTarget.edit(detail.name);
                  ref.read(workspaceModeProvider.notifier).state =
                      WorkspaceMode.agentEditor;
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete agent',
                iconSize: 18,
                onPressed: () =>
                    _showDeleteConfirmation(context, detail.name, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Avatar + name row
          Row(
            children: <Widget>[
              AgentAvatar(
                label: _avatarLabel(detail.name),
                accentColor: detail.color,
                size: 48,
                isActive: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(detail.name, style: textTheme.titleMedium),
                    if (detail.model != null)
                      Text(
                        detail.model!,
                        style: textTheme.bodySmall?.copyWith(
                          color: ManfredColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (detail.description != null &&
              detail.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(detail.description!, style: textTheme.bodyMedium),
          ],

          if (detail.tools.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Tools',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detail.tools
                  .map(
                    (tool) => Chip(
                      label: Text(
                        tool,
                        style: textTheme.labelSmall,
                      ),
                      backgroundColor: ManfredColors.panelAltBackground,
                      side: const BorderSide(color: ManfredColors.borderSubtle),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (detail.systemPrompt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('System prompt', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            _CollapsibleText(text: detail.systemPrompt),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String agentName,
    WidgetRef ref,
  ) async {
    List<SessionListEntry> sessions;
    try {
      sessions =
          await ref.read(agentsRepositoryProvider).getAgentSessions(agentName);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load agent sessions')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final sessionCount = sessions.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ManfredColors.panelAltBackground,
        title: const Text('Delete agent'),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(ctx).style,
            children: <TextSpan>[
              TextSpan(
                text: 'Are you sure you want to delete agent "$agentName"?\n\n',
              ),
              TextSpan(
                text: sessionCount > 0
                    ? 'This will also delete $sessionCount session(s).'
                    : 'This agent has no sessions.',
                style: TextStyle(
                  color: sessionCount > 0 ? Colors.red : null,
                  fontWeight: sessionCount > 0 ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(agentsRepositoryProvider).deleteAgent(agentName);
      await ref.read(agentsListProvider.notifier).refresh();
      ref.read(selectedAgentNameProvider.notifier).state = kDefaultAgentName;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete agent: $e')),
        );
      }
    }
  }

  String _avatarLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final segments = trimmed.split(RegExp(r'[^a-zA-Z0-9]'));
    final chars = segments.where((s) => s.isNotEmpty).map((s) => s[0]).toList();
    if (chars.length >= 2) return '${chars[0]}${chars[1]}'.toUpperCase();
    if (trimmed.length >= 2) return trimmed.substring(0, 2).toUpperCase();
    return trimmed[0].toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Collapsible text widget
// ---------------------------------------------------------------------------

class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText({required this.text});

  final String text;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const int _previewLength = 200;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLong = widget.text.length > _previewLength;
    final displayText = _expanded || !isLong
        ? widget.text
        : '${widget.text.substring(0, _previewLength)}...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(
            displayText,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'JetBrains Mono',
              color: ManfredColors.textSecondary,
            ),
          ),
          if (isLong) ...<Widget>[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Show all',
                style: textTheme.labelSmall?.copyWith(
                  color: ManfredColors.accentBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
