import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../controls/workspace_icon_button.dart';
import '../controls/workspace_outline_button.dart';
import '../sessions/session_list_item.dart';

class SessionsColumn extends StatelessWidget {
  const SessionsColumn({
    super.key,
    required this.sessions,
    required this.rootAgent,
    required this.isLoading,
    required this.errorMessage,
    required this.onCreateSession,
    required this.onSelectSession,
    required this.onRetry,
    this.compact = false,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final List<SessionMock> sessions;
  final String rootAgent;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onCreateSession;
  final ValueChanged<SessionMock> onSelectSession;
  final VoidCallback onRetry;
  final bool compact;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactSessionsColumn(
        sessions: sessions,
        rootAgent: rootAgent,
        isLoading: isLoading,
        errorMessage: errorMessage,
        onCreateSession: onCreateSession,
        onSelectSession: onSelectSession,
        onRetry: onRetry,
      );
    }

    if (collapsed) {
      return _CollapsedSessionsColumn(
        sessions: sessions,
        onSelectSession: onSelectSession,
        onToggleCollapse: onToggleCollapse,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textTheme = Theme.of(context).textTheme;
        final useCompactAction = constraints.maxWidth < 240;

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Sessions', style: textTheme.titleMedium),
              const SizedBox(height: 18),
              if (useCompactAction)
                WorkspaceIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'New session',
                  onTap: onCreateSession,
                  isPrimary: true,
                )
              else
                WorkspaceOutlineButton(
                  icon: Icons.add_rounded,
                  label: 'New Session',
                  onTap: onCreateSession,
                ),
              const SizedBox(height: 20),
              Expanded(
                child: _SessionsBody(
                  sessions: sessions,
                  isLoading: isLoading,
                  errorMessage: errorMessage,
                  onSelectSession: onSelectSession,
                  onRetry: onRetry,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactSessionsColumn extends StatelessWidget {
  const _CompactSessionsColumn({
    required this.sessions,
    required this.rootAgent,
    required this.isLoading,
    required this.errorMessage,
    required this.onCreateSession,
    required this.onSelectSession,
    required this.onRetry,
  });

  final List<SessionMock> sessions;
  final String rootAgent;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onCreateSession;
  final ValueChanged<SessionMock> onSelectSession;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 198,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Root agent: $rootAgent',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            WorkspaceOutlineButton(
              icon: Icons.add_rounded,
              label: 'New Session',
              onTap: onCreateSession,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _SessionsBody(
                sessions: sessions,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onSelectSession: onSelectSession,
                onRetry: onRetry,
                horizontal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedSessionsColumn extends StatelessWidget {
  const _CollapsedSessionsColumn({
    required this.sessions,
    required this.onSelectSession,
    required this.onToggleCollapse,
  });

  final List<SessionMock> sessions;
  final ValueChanged<SessionMock> onSelectSession;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        children: <Widget>[
          WorkspaceIconButton(
            icon: Icons.keyboard_double_arrow_right_rounded,
            tooltip: 'Expand sessions',
            onTap: onToggleCollapse ?? () {},
          ),
          const SizedBox(height: 18),
          Text(
            'SESS',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: ManfredColors.textMuted),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return SizedBox(
                  height: 64,
                  child: SessionListItem(
                    session: session,
                    compact: true,
                    onTap: () => onSelectSession(session),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsBody extends StatelessWidget {
  const _SessionsBody({
    required this.sessions,
    required this.isLoading,
    required this.errorMessage,
    required this.onSelectSession,
    required this.onRetry,
    this.horizontal = false,
  });

  final List<SessionMock> sessions;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<SessionMock> onSelectSession;
  final VoidCallback onRetry;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (errorMessage != null) {
      return _StateMessage(
        message: 'Nie udało się załadować sesji.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    if (sessions.isEmpty) {
      return const _StateMessage(message: 'Brak sesji.');
    }

    return ListView.separated(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      itemCount: sessions.length,
      separatorBuilder: (_, _) =>
          SizedBox(width: horizontal ? 10 : 0, height: horizontal ? 0 : 2),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final child = SessionListItem(
          session: session,
          compact: horizontal,
          onTap: () => onSelectSession(session),
        );

        if (!horizontal) {
          return child;
        }

        return SizedBox(width: 132, child: child);
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
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
