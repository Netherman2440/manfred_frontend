import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';
import 'workspace_icon_button.dart';

class ComposerMock extends StatelessWidget {
  const ComposerMock({super.key, required this.showCompactLayout});

  final bool showCompactLayout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        showCompactLayout ? 14 : 22,
        14,
        showCompactLayout ? 14 : 22,
        18,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ManfredColors.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          WorkspaceIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Attach',
            onTap: () {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ManfredColors.panelAltBackground,
                borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
                border: Border.all(color: ManfredColors.borderSubtle),
              ),
              child: Text(
                'Napisz wiadomość do sesji...',
                style: textTheme.bodyMedium?.copyWith(
                  color: ManfredColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          WorkspaceIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Send',
            isPrimary: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
