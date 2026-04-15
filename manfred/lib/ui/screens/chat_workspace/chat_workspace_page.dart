import 'package:flutter/material.dart';

import '../../mock/manfred_mock_data.dart';
import '../../theme/manfred_theme.dart';
import 'layout/desktop_workspace_layout.dart';
import 'layout/mobile_workspace_layout.dart';

class ChatWorkspacePage extends StatelessWidget {
  const ChatWorkspacePage({super.key, required this.workspace});

  final WorkspaceMock workspace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ManfredColors.appBackground,
              Color(0xFF14100D),
              ManfredColors.appBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return MobileWorkspaceLayout(workspace: workspace);
              }

              return DesktopWorkspaceLayout(
                workspace: workspace,
                showAgentColumn: constraints.maxWidth >= 960,
                showAdditionalColumn: constraints.maxWidth >= 1280,
              );
            },
          ),
        ),
      ),
    );
  }
}
