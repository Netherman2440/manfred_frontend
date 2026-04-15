import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';

class WorkspaceIconButton extends StatefulWidget {
  const WorkspaceIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<WorkspaceIconButton> createState() => _WorkspaceIconButtonState();
}

class _WorkspaceIconButtonState extends State<WorkspaceIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isPrimary
        ? (_isHovered
              ? ManfredColors.accentBlue.withValues(alpha: 0.9)
              : ManfredColors.accentBlue)
        : (_isHovered
              ? ManfredColors.messageHover
              : ManfredColors.panelAltBackground);

    final borderColor = widget.isPrimary
        ? ManfredColors.accentBlue.withValues(alpha: _isHovered ? 0.95 : 0.75)
        : (_isHovered
              ? ManfredColors.borderStrong
              : ManfredColors.borderSubtle);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
              border: Border.all(color: borderColor),
            ),
            child: Icon(
              widget.icon,
              color: widget.isPrimary
                  ? ManfredColors.appBackground
                  : ManfredColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
