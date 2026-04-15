import 'package:flutter/material.dart';

import '../../../core/agent_avatar.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../controls/workspace_icon_button.dart';

class WorkspaceAccountBar extends StatelessWidget {
  const WorkspaceAccountBar({
    super.key,
    required this.user,
    required this.width,
  });

  final CurrentUserMock user;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: ManfredColors.panelBackground,
          borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
          border: Border.all(color: ManfredColors.borderSubtle),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              AgentAvatar(label: user.label, accentColor: user.color, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.status,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: ManfredColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              WorkspaceIconButton(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
