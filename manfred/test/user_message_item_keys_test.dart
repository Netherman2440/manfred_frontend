import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/ui/mock/manfred_mock_data.dart';
import 'package:manfred/ui/screens/chat_workspace/conversation/items/user_message_item.dart';
import 'package:manfred/ui/theme/manfred_theme.dart';

void main() {
  Future<void> pumpEditor(
    WidgetTester tester, {
    required String initialDraft,
    required ValueChanged<String> onChanged,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ManfredTheme.dark(),
        home: Scaffold(
          body: UserMessageItem(
            entry: UserConversationEntryMock(
              dateLabel: '23.05.2026',
              timeLabel: '10:00',
              author: 'Igor',
              body: initialDraft,
              messageId: 'm1',
              canEdit: true,
              isEditing: true,
              editingDraft: initialDraft,
            ),
            onEditChanged: onChanged,
            onSaveEdit: onSave,
            onCancelEdit: onCancel,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Enter saves edit (no shift)', (tester) async {
    var saveCount = 0;
    await pumpEditor(
      tester,
      initialDraft: 'hello',
      onChanged: (_) {},
      onSave: () => saveCount += 1,
      onCancel: () {},
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(saveCount, 1);
  });

  testWidgets('Shift+Enter inserts newline and does NOT save', (tester) async {
    var saveCount = 0;
    var lastChanged = '';
    await pumpEditor(
      tester,
      initialDraft: 'hello',
      onChanged: (value) => lastChanged = value,
      onSave: () => saveCount += 1,
      onCancel: () {},
    );

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.userUpdateTextEditingValue(
      const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 5),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(saveCount, 0);
    expect(lastChanged, 'hello\n');
    expect(state.textEditingValue.text, 'hello\n');
    expect(state.textEditingValue.selection.baseOffset, 6);
  });

  testWidgets('Esc cancels edit', (tester) async {
    var cancelCount = 0;
    await pumpEditor(
      tester,
      initialDraft: 'hello',
      onChanged: (_) {},
      onSave: () {},
      onCancel: () => cancelCount += 1,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCount, 1);
  });
}
