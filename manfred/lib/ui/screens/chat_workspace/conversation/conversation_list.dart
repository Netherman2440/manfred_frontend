import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import 'items/agent_ping_item.dart';
import 'items/agent_message_item.dart';
import 'items/agent_thread_item.dart';
import 'items/tool_call_item.dart';
import 'items/user_message_item.dart';

class ConversationList extends StatelessWidget {
  const ConversationList({super.key, required this.entries});

  final List<ConversationEntryMock> entries;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entries
        .where(_shouldRenderEntry)
        .toList(growable: false);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      itemCount: visibleEntries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final entry = visibleEntries[index];
        return switch (entry) {
          UserConversationEntryMock() => UserMessageItem(entry: entry),
          AgentConversationEntryMock() => AgentMessageItem(entry: entry),
          ToolCallConversationEntryMock() => ToolCallItem(entry: entry),
          AgentPingConversationEntryMock() => AgentPingItem(entry: entry),
          AgentThreadConversationEntryMock() => AgentThreadItem(entry: entry),
        };
      },
    );
  }

  bool _shouldRenderEntry(ConversationEntryMock entry) {
    return entry is! ToolCallConversationEntryMock ||
        entry.toolName != 'delegate';
  }
}
