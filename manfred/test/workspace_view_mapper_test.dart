import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';
import 'package:manfred/features/sessions/presentation/workspace_view_mapper.dart';
import 'package:manfred/ui/mock/manfred_mock_data.dart';

void main() {
  test(
    'maps root items to the main transcript and subagent items to a thread',
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
                'call_id': 'call-1',
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
              agentId: 'agent-1',
              sequence: 2,
              createdAt: DateTime.parse('2026-04-22T09:01:00Z'),
              callId: 'call-1',
              name: 'delegate',
              arguments: <String, Object?>{
                'agent_name': 'research',
                'task': 'Sprawdź założenia person użytkowników.',
              },
            ),
            SessionMessageItem(
              id: 'worker-input',
              agentId: 'worker-1',
              sequence: 1,
              createdAt: DateTime.parse('2026-04-22T09:01:01Z'),
              role: 'user',
              content: 'Sprawdź założenia person użytkowników.',
            ),
            SessionToolCallItem(
              id: 'ask-user-call',
              agentId: 'worker-1',
              sequence: 2,
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
      expect(view.entries.whereType<UserConversationEntryMock>(), isEmpty);
      expect(view.entries.whereType<ToolCallConversationEntryMock>(), isEmpty);

      final threadEntry = view.entries
          .whereType<AgentThreadConversationEntryMock>()
          .single;
      expect(threadEntry.threadId, 'agent:worker-1');
      expect(threadEntry.statusLabel, 'Czeka na odpowiedź użytkownika.');

      final thread = view.threads.single;
      expect(thread.agentName, 'research');
      expect(
        thread.entries.whereType<AgentConversationEntryMock>().single.body,
        'Sprawdź założenia person użytkowników.',
      );
      expect(
        thread.entries.whereType<UserPingConversationEntryMock>().single.task,
        'Potrzebuję docelowej grupy użytkowników.',
      );
      expect(view.replyTarget, isNotNull);
      expect(view.replyTarget?.deliveryAgentId, 'agent-1');
      expect(view.replyTarget?.deliveryCallId, 'call-1');
      expect(view.replyTarget?.waitingAgentId, 'worker-1');
      expect(view.replyTarget?.agentName, 'research');
      expect(
        view.replyTarget?.description,
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
            agentId: 'agent-1',
            sequence: 1,
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
            agentId: 'agent-1',
            sequence: 2,
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
    expect(view.replyTarget, isNull);
  });

  test('maps answered ask_user in a thread to a user reply and clears waiting', () {
    final view = buildSessionViewMock(
      SessionDetails(
        session: SessionSummary(
          id: 'session-answered',
          userId: 'user-1',
          title: 'answered-ask-user',
          status: 'active',
          createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-22T09:03:00Z'),
        ),
        rootAgent: const RootAgentSummary(
          id: 'agent-1',
          name: 'Manfred',
          status: 'active',
          model: 'openrouter:test',
          waitingFor: <Map<String, Object?>>[
            <String, Object?>{
              'call_id': 'call-1',
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
            agentId: 'agent-1',
            sequence: 1,
            createdAt: DateTime.parse('2026-04-22T09:00:30Z'),
            callId: 'call-1',
            name: 'delegate',
            arguments: <String, Object?>{
              'agent_name': 'research',
              'task': 'Sprawdź założenia person użytkowników.',
            },
          ),
          SessionMessageItem(
            id: 'worker-input',
            agentId: 'worker-1',
            sequence: 1,
            createdAt: DateTime.parse('2026-04-22T09:01:00Z'),
            role: 'user',
            content: 'Sprawdź założenia person użytkowników.',
          ),
          SessionToolCallItem(
            id: 'ask-user-call',
            agentId: 'worker-1',
            sequence: 2,
            createdAt: DateTime.parse('2026-04-22T09:02:00Z'),
            callId: 'call-2',
            name: 'ask_user',
            arguments: <String, Object?>{
              'description': 'Potrzebuję docelowej grupy użytkowników.',
            },
          ),
          SessionToolResultItem(
            id: 'ask-user-output',
            agentId: 'worker-1',
            sequence: 3,
            createdAt: DateTime.parse('2026-04-22T09:02:30Z'),
            callId: 'call-2',
            name: 'ask_user',
            toolResult: <String, Object?>{
              'ok': true,
              'output': 'To jest produkt dla małych zespołów rekrutacyjnych.',
            },
            isError: false,
          ),
        ],
      ),
      currentUserName: 'NetHerman2440',
    );

    final threadEntry = view.entries
        .whereType<AgentThreadConversationEntryMock>()
        .single;
    expect(
      threadEntry.statusLabel,
      'W tym wątku nie ma nowych wiadomości.',
    );

    final thread = view.threads.single;
    expect(
      thread.entries.whereType<UserPingConversationEntryMock>().single.task,
      'Potrzebuję docelowej grupy użytkowników.',
    );
    expect(
      thread.entries.whereType<UserConversationEntryMock>().single.author,
      'NetHerman2440',
    );
    expect(
      thread.entries.whereType<UserConversationEntryMock>().single.body,
      'To jest produkt dla małych zespołów rekrutacyjnych.',
    );
    expect(view.replyTarget, isNull);
  });

  test('maps root ask_user waiting into a composer reply target', () {
    final view = buildSessionViewMock(
      SessionDetails(
        session: SessionSummary(
          id: 'session-3',
          userId: 'user-1',
          title: 'root-ask-user',
          status: 'active',
          createdAt: DateTime.parse('2026-04-22T09:00:00Z'),
          updatedAt: DateTime.parse('2026-04-22T09:01:00Z'),
        ),
        rootAgent: const RootAgentSummary(
          id: 'agent-root',
          name: 'Manfred',
          status: 'waiting',
          model: 'openrouter:test',
          waitingFor: <Map<String, Object?>>[
            <String, Object?>{
              'call_id': 'call-human',
              'type': 'human',
              'name': 'ask_user',
              'description': 'Doprecyzuj lokalizację zamku.',
              'agent_id': 'agent-root',
            },
          ],
        ),
        items: const <SessionItem>[],
      ),
      currentUserName: 'NetHerman2440',
    );

    expect(view.replyTarget, isNotNull);
    expect(view.replyTarget?.deliveryAgentId, 'agent-root');
    expect(view.replyTarget?.agentName, 'Manfred');
    expect(view.replyTarget?.deliveryCallId, 'call-human');
    expect(view.replyTarget?.toolName, 'ask_user');
  });
}
