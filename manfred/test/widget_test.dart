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

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('ui-foundation'), findsWidgets);
    expect(find.text('Artifacts'), findsOneWidget);
    expect(find.text('update_theme_tokens'), findsOneWidget);
    expect(find.text('session-rail-refresh'), findsWidgets);
  });
}
