import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../additional/highlight_card.dart';
import '../additional/resource_card.dart';
import '../controls/workspace_icon_button.dart';

class AdditionalColumn extends StatelessWidget {
  const AdditionalColumn({
    super.key,
    required this.data,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final RightRailMock data;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return _CollapsedAdditionalColumn(
        data: data,
        onToggleCollapse: onToggleCollapse,
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Artifacts', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Pliki, wątki i stan sesji',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onToggleCollapse != null)
                WorkspaceIconButton(
                  icon: Icons.keyboard_double_arrow_right_rounded,
                  tooltip: 'Collapse artifacts',
                  onTap: onToggleCollapse!,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: <Widget>[
                ...data.highlights.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HighlightCard(label: item.label, value: item.value),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Resources', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                ...data.resources.map(
                  (resource) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ResourceCard(resource: resource),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedAdditionalColumn extends StatelessWidget {
  const _CollapsedAdditionalColumn({
    required this.data,
    required this.onToggleCollapse,
  });

  final RightRailMock data;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(
        children: <Widget>[
          WorkspaceIconButton(
            icon: Icons.keyboard_double_arrow_left_rounded,
            tooltip: 'Expand artifacts',
            onTap: onToggleCollapse ?? () {},
          ),
          const SizedBox(height: 18),
          Text(
            'AR',
            style: textTheme.labelMedium?.copyWith(
              color: ManfredColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          _CountBadge(label: 'H', value: data.highlights.length),
          const SizedBox(height: 10),
          _CountBadge(label: 'R', value: data.resources.length),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: data.resources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Tooltip(
                  message: data.resources[index].title,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: ManfredColors.panelAltBackground,
                      borderRadius: BorderRadius.circular(
                        ManfredShapes.inputRadius,
                      ),
                      border: Border.all(color: ManfredColors.borderSubtle),
                    ),
                    child: Center(
                      child: Text(
                        data.resources[index].kind,
                        style: textTheme.labelSmall,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Column(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text('$value', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
