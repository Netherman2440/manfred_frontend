import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manfred/main.dart';

void main() {
  testWidgets('renders the static workspace mock', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ManfredApp());
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsWidgets);
    expect(find.text('ui-foundation'), findsWidgets);
    expect(find.text('Artifacts'), findsWidgets);
    expect(find.text('NetHerman2440'), findsWidgets);
    expect(find.text('Dostepny'), findsOneWidget);
    expect(
      find.textContaining('Potrzebuję nowych wariantów UI'),
      findsOneWidget,
    );
    expect(
      find.textContaining('@research', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Agent research rozpoczął wątek', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(
        '{"agent_name":"research","task":"Znajdź informacje o historii zamku lubelskiego."}',
      ),
      findsNothing,
    );
    expect(find.text('update_theme_tokens'), findsNothing);
    expect(find.text('session-rail-refresh'), findsNothing);
  });
}
