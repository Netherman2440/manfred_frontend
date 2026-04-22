import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';
import 'package:manfred/features/sessions/presentation/workspace_view_mapper.dart';
import 'package:manfred/ui/mock/manfred_mock_data.dart';

void main() {
  test(
    'maps delegate and waiting_for into conversational entries and thread',
    () {
      final view = buildSessionViewMock(
        SessionDetails(
          session: SessionSummary(
            id: 'session-1',
            userId: 'user-1',
            title: 'delegate-preview',
            status: 'active',
            createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
            updatedAt: DateTime.parse('2026-04-22T09:03:00Z'),
          ),
          rootAgent: const RootAgentSummary(
            id: 'agent-1',
            name: 'Manfred',
            status: 'waiting',
            model: 'openrouter:test',
            waitingFor: <Map<String, Object?>>[
              <String, Object?>{
                'type': 'agent',
                'name': 'delegate',
                'description': 'Potrzebuję docelowej grupy użytkowników.',
                'agent_id': 'worker-1',
              },
            ],
          ),
          items: <SessionItem>[
            SessionToolCallItem(
              id: 'delegate-call',
              createdAt: DateTime.parse('2026-04-22T09:01:00Z'),
              callId: 'call-1',
              name: 'delegate',
              arguments: <String, Object?>{
                'agent_name': 'research',
                'task': 'Sprawdź założenia person użytkowników.',
              },
            ),
            SessionToolCallItem(
              id: 'ask-user-call',
              createdAt: DateTime.parse('2026-04-22T09:02:00Z'),
              callId: 'call-2',
              name: 'ask_user',
              arguments: <String, Object?>{
                'description': 'Potrzebuję docelowej grupy użytkowników.',
              },
            ),
          ],
        ),
        currentUserName: 'NetHerman2440',
      );

      expect(
        view.entries
            .whereType<AgentPingConversationEntryMock>()
            .single
            .agentName,
        'research',
      );
      expect(view.entries.whereType<ToolCallConversationEntryMock>(), isEmpty);

      final threadEntry = view.entries
          .whereType<AgentThreadConversationEntryMock>()
          .single;
      expect(threadEntry.threadId, 'delegate:call-1');
      expect(threadEntry.statusLabel, 'Czeka na odpowiedź użytkownika.');

      final thread = view.threads.single;
      expect(thread.agentName, 'research');
      expect(
        thread.entries.whereType<UserPingConversationEntryMock>().single.task,
        'Potrzebuję docelowej grupy użytkowników.',
      );
    },
  );

  test('keeps regular tool calls on the standard renderer fallback', () {
    final view = buildSessionViewMock(
      SessionDetails(
        session: SessionSummary(
          id: 'session-2',
          userId: 'user-1',
          title: 'tool-preview',
          status: 'active',
          createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-22T09:01:00Z'),
        ),
        rootAgent: const RootAgentSummary(
          id: 'agent-1',
          name: 'Manfred',
          status: 'completed',
          model: 'openrouter:test',
          waitingFor: <Map<String, Object?>>[],
        ),
        items: <SessionItem>[
          SessionToolCallItem(
            id: 'search-call',
            createdAt: DateTime.parse('2026-04-22T09:00:30Z'),
            callId: 'call-search',
            name: 'search_docs',
            arguments: <String, Object?>{
              'query': 'workspace view mapper',
              'limit': 3,
            },
          ),
          SessionToolResultItem(
            id: 'search-output',
            createdAt: DateTime.parse('2026-04-22T09:00:31Z'),
            callId: 'call-search',
            name: 'search_docs',
            toolResult: <String, Object?>{'hits': 3},
            isError: false,
          ),
        ],
      ),
      currentUserName: 'NetHerman2440',
    );

    final toolEntry = view.entries
        .whereType<ToolCallConversationEntryMock>()
        .single;
    expect(toolEntry.toolName, 'search_docs');
    expect(
      toolEntry.argumentsJson,
      contains('"query": "workspace view mapper"'),
    );
    expect(toolEntry.outputJson, contains('"hits": 3'));
    expect(view.threads, isEmpty);
  });
}
