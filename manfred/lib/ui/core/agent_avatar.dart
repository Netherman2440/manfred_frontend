import 'package:flutter/material.dart';

import '../theme/manfred_theme.dart';

class AgentAvatar extends StatelessWidget {
  const AgentAvatar({
    super.key,
    required this.label,
    required this.accentColor,
    this.size = 42,
    this.backgroundColor = ManfredColors.panelOverlay,
    this.isActive = false,
  });

  final String label;
  final Color accentColor;
  final double size;
  final Color backgroundColor;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.45)
              : ManfredColors.borderSubtle,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: accentColor),
        ),
      ),
    );
  }
}
