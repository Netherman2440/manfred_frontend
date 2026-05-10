import 'package:flutter/material.dart';

import '../theme/manfred_theme.dart';

class AgentAvatar extends StatelessWidget {
  const AgentAvatar({
    super.key,
    this.imageUrl,
    this.label,
    this.accentColor,
    this.size = 42,
    this.backgroundColor = ManfredColors.panelOverlay,
    this.isActive = false,
  });

  final String? imageUrl;
  final String? label;
  final Color? accentColor;
  final double size;
  final Color backgroundColor;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveAccent = accentColor ?? ManfredColors.accentBlue;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? effectiveAccent.withValues(alpha: 0.45)
              : ManfredColors.borderSubtle,
        ),
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildInitials(
                  textTheme: textTheme,
                  accentColor: effectiveAccent,
                ),
              )
            : _buildInitials(
                textTheme: textTheme,
                accentColor: effectiveAccent,
              ),
      ),
    );
  }

  Widget _buildInitials({
    required TextTheme textTheme,
    required Color accentColor,
  }) {
    final displayLabel = _resolveLabel();
    return Center(
      child: Text(
        displayLabel,
        style: textTheme.labelLarge?.copyWith(color: accentColor),
      ),
    );
  }

  String _resolveLabel() {
    if (label == null || label!.isEmpty) return '?';
    return label!;
  }
}
