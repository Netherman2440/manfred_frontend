import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import 'items/agent_message_item.dart';
import 'items/user_message_item.dart';

class ConversationList extends StatelessWidget {
  const ConversationList({super.key, required this.entries});

  final List<ConversationEntryMock> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return switch (entry.type) {
          ConversationEntryType.user => UserMessageItem(entry: entry),
          ConversationEntryType.agent => AgentMessageItem(entry: entry),
        };
      },
    );
  }
}
