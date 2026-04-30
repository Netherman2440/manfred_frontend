import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../controls/composer_mock.dart';
import '../conversation/conversation_list.dart';
import '../controls/workspace_outline_button.dart';

class ConversationColumn extends StatelessWidget {
  const ConversationColumn({
    super.key,
    required this.sessionView,
    required this.showCompactHeader,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    this.selectedThreadId,
    this.onSelectThread,
  });

  final SessionViewMock sessionView;
  final bool showCompactHeader;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final String? selectedThreadId;
  final ValueChanged<String>? onSelectThread;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        if (showCompactHeader) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(sessionView.title, style: textTheme.titleLarge),
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: switch ((
            isLoading,
            errorMessage != null,
            sessionView.entries.isEmpty && !sessionView.isAgentTyping,
          )) {
            (true, _, _) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            (_, true, _) => _ConversationMessage(
              message: 'Nie udało się załadować historii sesji.',
              actionLabel: 'Retry',
              onAction: onRetry,
            ),
            (_, _, true) => const _ConversationMessage(
              message: 'Nowa sesja jest pusta. Wyślij pierwszą wiadomość.',
            ),
            _ => ConversationList(
              entries: sessionView.entries,
              showTypingIndicator: sessionView.isAgentTyping,
              typingAuthor: sessionView.rootAgent,
              selectedThreadId: selectedThreadId,
              onSelectThread: onSelectThread,
            ),
          },
        ),
        ComposerMock(
          showCompactLayout: showCompactHeader,
          replyTarget: sessionView.replyTarget,
          rootAgentName: sessionView.rootAgent,
        ),
      ],
    );
  }
}

class _ConversationMessage extends StatelessWidget {
  const _ConversationMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: ManfredColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 14),
              WorkspaceOutlineButton(
                icon: Icons.refresh_rounded,
                label: actionLabel!,
                onTap: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
