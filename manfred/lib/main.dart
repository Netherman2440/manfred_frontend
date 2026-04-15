import 'package:flutter/material.dart';

import 'ui/mock/manfred_mock_data.dart';
import 'ui/screens/chat_workspace_page.dart';
import 'ui/theme/manfred_theme.dart';

void main() {
  runApp(const ManfredApp());
}

class ManfredApp extends StatelessWidget {
  const ManfredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manfred UI Mock',
      debugShowCheckedModeBanner: false,
      theme: ManfredTheme.dark(),
      home: const ChatWorkspacePage(workspace: ManfredMockData.workspace),
    );
  }
}
