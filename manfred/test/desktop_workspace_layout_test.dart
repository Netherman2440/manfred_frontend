import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/ui/mock/manfred_mock_data.dart';
import 'package:manfred/ui/screens/chat_workspace/layout/desktop_workspace_layout.dart';
import 'package:manfred/ui/theme/manfred_theme.dart';

void main() {
  testWidgets('additional column can be expanded with a resize handle', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ManfredTheme.dark(),
          home: Scaffold(
            body: DesktopWorkspaceLayout(
              workspace: ManfredMockData.workspace,
              showAgentColumn: true,
              showAdditionalColumn: true,
              sessionsLoading: false,
              sessionsErrorMessage: null,
              conversationLoading: false,
              conversationErrorMessage: null,
              onCreateSession: () {},
              onSelectSession: (_) {},
              onRetrySessions: () {},
              onRetryConversation: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final initialWidth = tester
        .getSize(find.byKey(const ValueKey('additional-panel')))
        .width;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('additional-resize-handle'))),
    );
    await gesture.moveBy(const Offset(-120, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final expandedWidth = tester
        .getSize(find.byKey(const ValueKey('additional-panel')))
        .width;

    expect(expandedWidth, greaterThan(initialWidth));
  });
}
