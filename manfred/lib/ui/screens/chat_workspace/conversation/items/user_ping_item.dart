import 'package:flutter/material.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';
import 'conversation_entry_header.dart';

class UserPingItem extends StatelessWidget {
  const UserPingItem({super.key, required this.entry});

  final UserPingConversationEntryMock entry;

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
            accentColor: ManfredColors.accentAmber,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConversationEntryHeader(
                  author: entry.author,
                  dateLabel: entry.dateLabel,
                  timeLabel: entry.timeLabel,
                  authorColor: ManfredColors.accentAmber,
                ),
                const SizedBox(height: 8),
                SelectableText.rich(
                  TextSpan(
                    style: textTheme.bodyMedium,
                    children: <InlineSpan>[
                      TextSpan(
                        text: '@${entry.userName} ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: ManfredColors.accentAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: entry.task),
                    ],
                  ),
                ),
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
