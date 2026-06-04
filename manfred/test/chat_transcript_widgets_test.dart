import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      ProviderScope(
        child: MaterialApp(
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
      ProviderScope(
        child: MaterialApp(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Uzupełnij kontekst biznesowy.'), findsNothing);

    await tester.tap(find.text('@research').last);
    await tester.pumpAndSettle();

    expect(find.text('Artifacts'), findsOneWidget);
    expect(
      find.textContaining('Uzupełnij kontekst biznesowy.'),
      findsOneWidget,
    );
    expect(find.text('Czeka na odpowiedź użytkownika.'), findsWidgets);
  });

  testWidgets('user message shows edit icon on hover and edits inline', (
    WidgetTester tester,
  ) async {
    var draft = 'Aktualizuję brief.';
    var isEditing = false;
    var saveTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ManfredTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ConversationList(
              entries: <ConversationEntryMock>[
                UserConversationEntryMock(
                  author: 'NetHerman2440',
                  dateLabel: '30.04.2026',
                  timeLabel: '10:15',
                  body: 'Aktualizuję brief.',
                  messageId: 'message-1',
                  isEdited: true,
                  pendingStatus: 'queued',
                  canEdit: true,
                  isEditing: isEditing,
                  editingDraft: draft,
                  attachments: const <ConversationAttachmentMock>[
                    ConversationAttachmentMock(
                      id: 'attachment-1',
                      fileName: 'brief.pdf',
                      mediaType: 'application/pdf',
                      sizeBytes: 2048,
                      path: '/tmp/brief.pdf',
                    ),
                  ],
                ),
              ],
              onEditUserMessage: (_) {
                setState(() {
                  isEditing = true;
                });
              },
              onEditUserMessageDraftChanged: (value) {
                setState(() {
                  draft = value;
                });
              },
              onCancelEditUserMessage: () {
                setState(() {
                  isEditing = false;
                });
              },
              onSaveEditUserMessage: () {
                saveTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Edited'), findsNothing);
    expect(find.text('Queued'), findsNothing);
    expect(find.textContaining('brief.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Aktualizuję brief.')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(
      find.text('Esc anuluje, Enter zapisuje, Shift+Enter nowa linia'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Nowa treść');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(draft, 'Nowa treść');
    expect(saveTapped, isTrue);
  });
}
