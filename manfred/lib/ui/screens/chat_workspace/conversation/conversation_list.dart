import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import 'items/agent_ping_item.dart';
import 'items/agent_typing_indicator_item.dart';
import 'items/agent_message_item.dart';
import 'items/agent_thread_item.dart';
import 'items/tool_call_item.dart';
import 'items/user_ping_item.dart';
import 'items/user_message_item.dart';

class ConversationList extends StatelessWidget {
  const ConversationList({
    super.key,
    required this.entries,
    this.showTypingIndicator = false,
    this.typingAuthor,
    this.selectedThreadId,
    this.onSelectThread,
    this.padding = const EdgeInsets.fromLTRB(24, 18, 24, 24),
  });

  final List<ConversationEntryMock> entries;
  final bool showTypingIndicator;
  final String? typingAuthor;
  final String? selectedThreadId;
  final ValueChanged<String>? onSelectThread;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final itemCount = entries.length + (showTypingIndicator ? 1 : 0);

    return SelectionArea(
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          if (showTypingIndicator && index == itemCount - 1) {
            return AgentTypingIndicatorItem(author: typingAuthor ?? 'Manfred');
          }

          final entry = entries[index];
          return switch (entry) {
            UserConversationEntryMock() => UserMessageItem(entry: entry),
            AgentConversationEntryMock() => AgentMessageItem(entry: entry),
            ToolCallConversationEntryMock() => ToolCallItem(entry: entry),
            AgentPingConversationEntryMock() => AgentPingItem(entry: entry),
            UserPingConversationEntryMock() => UserPingItem(entry: entry),
            AgentThreadConversationEntryMock() => AgentThreadItem(
              entry: entry,
              isSelected: entry.threadId == selectedThreadId,
              onTap: onSelectThread == null
                  ? null
                  : () => onSelectThread!(entry.threadId),
            ),
          };
        },
      ),
    );
  }
}
