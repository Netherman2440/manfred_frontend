import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../additional/highlight_card.dart';
import '../additional/resource_card.dart';

class AdditionalColumn extends StatelessWidget {
  const AdditionalColumn({super.key, required this.data});

  final RightRailMock data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Artifacts', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Pliki, watki i stan sesji', style: textTheme.bodySmall),
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
