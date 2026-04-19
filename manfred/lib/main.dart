import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/chat_workspace/chat_workspace_page.dart';
import 'ui/theme/manfred_theme.dart';

void main() {
  runApp(const ProviderScope(child: ManfredApp()));
}

class ManfredApp extends StatelessWidget {
  const ManfredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manfred',
      debugShowCheckedModeBanner: false,
      theme: ManfredTheme.dark(),
      home: const ChatWorkspacePage(),
    );
  }
}
