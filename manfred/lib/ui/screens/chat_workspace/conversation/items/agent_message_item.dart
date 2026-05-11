import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../../features/agents/application/agent_editor_provider.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';
import 'conversation_entry_header.dart';

class AgentMessageItem extends ConsumerWidget {
  const AgentMessageItem({super.key, required this.entry});

  final AgentConversationEntryMock entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final agentDetail = ref.watch(agentDetailByNameProvider(entry.author));
    final agentColor =
        agentDetail.valueOrNull?.color ?? ManfredColors.accentGreen;

    return HoverTileContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AgentAvatar(
            label: _avatarLabel(entry.author),
            accentColor: agentColor,
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
                  authorColor: agentColor,
                ),
                const SizedBox(height: 8),
                SelectableText(entry.body, style: textTheme.bodyMedium),
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
