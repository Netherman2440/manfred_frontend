import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/ui/mock/manfred_mock_data.dart';
import 'package:manfred/ui/screens/chat_workspace/columns/additional_column.dart';
import 'package:manfred/ui/screens/chat_workspace/conversation/conversation_list.dart';
import 'package:manfred/ui/theme/manfred_theme.dart';

void main() {
  testWidgets('tool call preview expands without repeating the collapsed line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ManfredTheme.dark(),
        home: Scaffold(
          body: ConversationList(
            entries: <ConversationEntryMock>[
              ToolCallConversationEntryMock(
                author: 'Manfred',
                dateLabel: '22.04.2026',
                timeLabel: '09:10',
                toolName: 'search_docs',
                argumentsPreview:
                    '{"query":"workspace view mapper","limit":3,"include_snippets":true}',
                argumentsJson:
                    '{\n  "query": "workspace view mapper",\n  "limit": 3,\n  "include_snippets": true\n}',
                outputPreview: '{"hits":3}',
                outputJson: '{\n  "hits": 3\n}',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(
      find.text(
        '{"query":"workspace view mapper","limit":3,"include_snippets":true}',
      ),
      findsOneWidget,
    );
    expect(find.text('arguments'), findsNothing);

    await tester.tap(find.text('Tool preview'));
    await tester.pumpAndSettle();

    expect(find.text('arguments'), findsOneWidget);
    expect(find.text('output'), findsOneWidget);
    expect(
      find.text(
        '{"query":"workspace view mapper","limit":3,"include_snippets":true}',
      ),
      findsNothing,
    );
    expect(
      find.textContaining('"query": "workspace view mapper"'),
      findsOneWidget,
    );
  });

  testWidgets('thread card opens delegated transcript in additional column', (
    WidgetTester tester,
  ) async {
    final sessionView = SessionViewMock(
      title: 'delegate-preview',
      rootAgent: 'Manfred',
      entries: <ConversationEntryMock>[
        const AgentPingConversationEntryMock(
          author: 'Manfred',
          dateLabel: '22.04.2026',
          timeLabel: '09:10',
          agentName: 'research',
          task: 'Sprawdź luki w briefie.',
        ),
        const AgentThreadConversationEntryMock(
          author: 'research',
          dateLabel: '22.04.2026',
          timeLabel: '09:11',
          threadId: 'delegate:call-1',
          agentName: 'research',
          taskPreview: 'Sprawdź luki w briefie.',
          threadTitle: '@research',
          threadMeta: '1 wpis',
          statusLabel: 'Czeka na odpowiedź użytkownika.',
        ),
      ],
      threads: <ConversationThreadMock>[
        const ConversationThreadMock(
          id: 'delegate:call-1',
          agentName: 'research',
          title: '@research',
          task: 'Sprawdź luki w briefie.',
          statusLabel: 'Czeka na odpowiedź użytkownika.',
          metaLabel: '1 wpis',
          entries: <ConversationEntryMock>[
            UserPingConversationEntryMock(
              author: 'research',
              dateLabel: '22.04.2026',
              timeLabel: '09:12',
              userName: 'NetHerman2440',
              task: 'Uzupełnij kontekst biznesowy.',
            ),
          ],
        ),
      ],
    );

    String? selectedThreadId;

    await tester.pumpWidget(
      MaterialApp(
        theme: ManfredTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Material(
                color: Colors.transparent,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ConversationList(
                        entries: sessionView.entries,
                        selectedThreadId: selectedThreadId,
                        onSelectThread: (threadId) {
                          setState(() {
                            selectedThreadId = selectedThreadId == threadId
                                ? null
                                : threadId;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: AdditionalColumn(
                        data: ManfredMockData.workspace.rightRail,
                        sessionView: sessionView,
                        selectedThreadId: selectedThreadId,
                        onClearThreadSelection: () {
                          setState(() {
                            selectedThreadId = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artifacts'), findsOneWidget);
    expect(find.textContaining('Uzupełnij kontekst biznesowy.'), findsNothing);

    await tester.tap(find.text('@research').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Uzupełnij kontekst biznesowy.'),
      findsOneWidget,
    );
    expect(find.text('Czeka na odpowiedź użytkownika.'), findsWidgets);
  });
}
