import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';

class WorkspaceOutlineButton extends StatefulWidget {
  const WorkspaceOutlineButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<WorkspaceOutlineButton> createState() => _WorkspaceOutlineButtonState();
}

class _WorkspaceOutlineButtonState extends State<WorkspaceOutlineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = _isHovered
        ? ManfredColors.borderStrong
        : ManfredColors.borderSubtle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        onTap: widget.onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? ManfredColors.messageHover
                : ManfredColors.panelBackground,
            borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(widget.icon, size: 18, color: ManfredColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: textTheme.labelLarge?.copyWith(
                  color: _isHovered
                      ? ManfredColors.textPrimary
                      : ManfredColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
