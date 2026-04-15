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
    this.compact = false,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final List<SessionMock> sessions;
  final String rootAgent;
  final bool compact;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactSessionsColumn(sessions: sessions, rootAgent: rootAgent);
    }

    if (collapsed) {
      return _CollapsedSessionsColumn(
        sessions: sessions,
        onToggleCollapse: onToggleCollapse,
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Sessions', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Root agent: $rootAgent', style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          WorkspaceOutlineButton(
            icon: Icons.add_rounded,
            label: 'New Session',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                return SessionListItem(session: sessions[index], onTap: () {});
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSessionsColumn extends StatelessWidget {
  const _CompactSessionsColumn({
    required this.sessions,
    required this.rootAgent,
  });

  final List<SessionMock> sessions;
  final String rootAgent;

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
              onTap: () {},
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 132,
                    child: SessionListItem(
                      session: sessions[index],
                      compact: true,
                      onTap: () {},
                    ),
                  );
                },
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
    required this.onToggleCollapse,
  });

  final List<SessionMock> sessions;
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
                return SizedBox(
                  height: 64,
                  child: SessionListItem(
                    session: sessions[index],
                    compact: true,
                    onTap: () {},
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
