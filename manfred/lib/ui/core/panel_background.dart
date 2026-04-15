import 'package:flutter/material.dart';

import '../theme/manfred_theme.dart';

class PanelBackground extends StatelessWidget {
  const PanelBackground({
    super.key,
    required this.child,
    this.background = ManfredColors.panelBackground,
  });

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: panelBackgroundDecoration(background: background),
      child: child,
    );
  }
}

BoxDecoration panelBackgroundDecoration({
  Color background = ManfredColors.panelBackground,
}) {
  return BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
    border: Border.all(color: ManfredColors.borderSubtle),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 22,
        offset: Offset(0, 12),
      ),
    ],
  );
}
