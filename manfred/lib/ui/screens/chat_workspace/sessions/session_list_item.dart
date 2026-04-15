import 'package:flutter/material.dart';

import '../../../core/hover_tile_container.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';

class SessionListItem extends StatelessWidget {
  const SessionListItem({
    super.key,
    required this.session,
    this.onTap,
    this.compact = false,
  });

  final SessionMock session;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (compact) {
      return Tooltip(
        message: session.title,
        child: HoverTileContainer(
          onTap: onTap,
          isActive: session.isActive,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Center(
            child: Text(
              _compactLabel(session.title),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: session.isActive
                    ? ManfredColors.textPrimary
                    : ManfredColors.textSecondary,
                height: 1.15,
              ),
            ),
          ),
        ),
      );
    }

    return HoverTileContainer(
      onTap: onTap,
      isActive: session.isActive,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        minLeadingWidth: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ManfredShapes.tileRadius),
        ),
        leading: Text(
          session.prefix,
          style: textTheme.titleMedium?.copyWith(
            color: session.isActive
                ? ManfredColors.textPrimary
                : ManfredColors.textMuted,
          ),
        ),
        title: Text(
          session.title,
          style: textTheme.bodyMedium?.copyWith(
            color: session.isActive
                ? ManfredColors.textPrimary
                : ManfredColors.textSecondary,
            fontWeight: session.isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  String _compactLabel(String title) {
    final normalized = title
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(3)
        .join(' ');

    if (normalized.isNotEmpty) {
      return normalized;
    }

    return title;
  }
}
