import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';

class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(value, style: textTheme.labelLarge),
        ],
      ),
    );
  }
}
