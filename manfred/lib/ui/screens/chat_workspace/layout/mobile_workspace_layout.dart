import 'package:flutter/material.dart';

import '../../../core/panel_background.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../columns/agent_column.dart';
import '../columns/conversation_column.dart';
import '../columns/sessions_column.dart';

class MobileWorkspaceLayout extends StatelessWidget {
  const MobileWorkspaceLayout({super.key, required this.workspace});

  final WorkspaceMock workspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: PanelBackground(
            child: AgentColumn(agents: workspace.agents, compact: true),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: PanelBackground(
            background: ManfredColors.sessionsBackground,
            child: SessionsColumn(
              sessions: workspace.sessions,
              rootAgent: workspace.sessionView.rootAgent,
              compact: true,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: PanelBackground(
              child: ConversationColumn(
                sessionView: workspace.sessionView,
                showCompactHeader: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
