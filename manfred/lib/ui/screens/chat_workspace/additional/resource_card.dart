import 'package:flutter/material.dart';

import '../../../core/hover_tile_container.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';

class ResourceCard extends StatelessWidget {
  const ResourceCard({super.key, required this.resource});

  final RailResourceMock resource;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return HoverTileContainer(
      onTap: () {},
      baseColor: ManfredColors.panelBackground,
      highlightColor: ManfredColors.panelAltBackground,
      borderRadius: ManfredShapes.inputRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          border: Border.all(color: ManfredColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ResourceKindPill(label: resource.kind),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(resource.title, style: textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(resource.meta, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ResourceKindPill extends StatelessWidget {
  const _ResourceKindPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ManfredColors.accentBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ManfredColors.accentBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: ManfredColors.accentBlue),
      ),
    );
  }
}
