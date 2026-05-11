import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../additional/agent_detail_view.dart';
import '../conversation/conversation_list.dart';
import '../controls/workspace_outline_button.dart';

class AdditionalColumn extends ConsumerWidget {
  const AdditionalColumn({
    super.key,
    required this.data,
    required this.sessionView,
    this.selectedThreadId,
    this.onClearThreadSelection,
  });

  final RightRailMock data;
  final SessionViewMock sessionView;
  final String? selectedThreadId;
  final VoidCallback? onClearThreadSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ConversationThreadMock? selectedThread;
    for (final thread in sessionView.threads) {
      if (thread.id == selectedThreadId) {
        selectedThread = thread;
        break;
      }
    }

    if (selectedThread != null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: _ThreadView(
          thread: selectedThread,
          onClear: onClearThreadSelection,
        ),
      );
    }

    return AgentDetailView();
  }
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({required this.thread, this.onClear});

  final ConversationThreadMock thread;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onClear != null) ...<Widget>[
          WorkspaceOutlineButton(
            icon: Icons.arrow_back_rounded,
            label: 'Artifacts',
            onTap: onClear!,
          ),
          const SizedBox(height: 16),
        ],
        Text(thread.title, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        SelectableText(
          thread.task,
          style: textTheme.bodySmall?.copyWith(
            color: ManfredColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (thread.metaLabel != null)
          Text(
            thread.metaLabel!,
            style: textTheme.labelSmall?.copyWith(
              color: ManfredColors.textMuted,
            ),
          ),
        const SizedBox(height: 6),
        SelectableText(
          thread.statusLabel,
          style: textTheme.bodySmall?.copyWith(color: ManfredColors.accentBlue),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: thread.entries.isEmpty
              ? _ThreadPlaceholder(
                  label:
                      thread.placeholderLabel ??
                      'Wątek jest gotowy na transcript subagenta.',
                )
              : ConversationList(
                  entries: thread.entries,
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                ),
        ),
      ],
    );
  }
}

class _ThreadPlaceholder extends StatelessWidget {
  const _ThreadPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: SelectableText(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: ManfredColors.textSecondary,
        ),
      ),
    );
  }
}
