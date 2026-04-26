import 'package:flutter/material.dart';

import '../theme/manfred_theme.dart';

class HoverTileContainer extends StatefulWidget {
  const HoverTileContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.isActive = false,
    this.baseColor = Colors.transparent,
    this.highlightColor = ManfredColors.messageHover,
    this.borderRadius = ManfredShapes.tileRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isActive;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;

  @override
  State<HoverTileContainer> createState() => _HoverTileContainerState();
}

class _HoverTileContainerState extends State<HoverTileContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final isHighlighted = widget.isActive || (isInteractive && _isHovered);

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: isInteractive ? (_) => setState(() => _isHovered = true) : null,
      onExit: isInteractive ? (_) => setState(() => _isHovered = false) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: isHighlighted ? widget.highlightColor : widget.baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
