import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../controls/workspace_icon_button.dart';

class DesktopWorkspaceTopBar extends StatelessWidget {
  const DesktopWorkspaceTopBar({
    super.key,
    required this.workspace,
    required this.showAgentColumn,
    required this.sessionsWidth,
    required this.showAdditionalColumn,
    required this.showResizeGap,
    required this.onToggleAdditionalColumn,
  });

  final WorkspaceMock workspace;
  final bool showAgentColumn;
  final double sessionsWidth;
  final bool showAdditionalColumn;
  final bool showResizeGap;
  final VoidCallback onToggleAdditionalColumn;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: ManfredColors.panelBackground,
        border: Border(bottom: BorderSide(color: ManfredColors.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          if (showAgentColumn)
            SizedBox(
              width: 92,
              child: Center(
                child: WorkspaceIconButton(
                  icon: Icons.home_rounded,
                  tooltip: 'Home',
                  onTap: () {},
                ),
              ),
            ),
          SizedBox(
            width: sessionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.view_list_rounded, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TopBarLabel(
                      title: workspace.sessionView.rootAgent,
                      subtitle: 'Root agent',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showResizeGap) const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      workspace.sessionView.title,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  WorkspaceIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: showAdditionalColumn
                        ? 'Hide artifacts'
                        : 'Show artifacts',
                    onTap: onToggleAdditionalColumn,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarLabel extends StatelessWidget {
  const _TopBarLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall,
        ),
      ],
    );
  }
}
