import 'package:flutter/material.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';

class AgentMessageItem extends StatelessWidget {
  const AgentMessageItem({super.key, required this.entry});

  final ConversationEntryMock entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return HoverTileContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AgentAvatar(
            label: _avatarLabel(entry.author),
            accentColor: ManfredColors.accentGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      entry.author,
                      style: textTheme.labelLarge?.copyWith(
                        color: ManfredColors.accentGreen,
                      ),
                    ),
                    Text(
                      '${entry.dateLabel} ${entry.timeLabel}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(entry.body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _avatarLabel(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }
}
