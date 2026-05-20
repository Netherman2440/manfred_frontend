import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/chat/application/summarize_snackbar_emitter.dart';
import 'features/user/application/user_me_provider.dart';
import 'ui/screens/chat_workspace/chat_workspace_page.dart';
import 'ui/screens/chat_workspace/summarize_snackbar.dart';
import 'ui/theme/manfred_theme.dart';

/// Top-level [ScaffoldMessengerState] key — shared between [MaterialApp]'s
/// `scaffoldMessengerKey` and the production [SummarizeSnackbarEmitter] so
/// the composer controller can deliver SnackBars from outside the widget
/// tree.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(
    ProviderScope(
      overrides: <Override>[
        summarizeSnackbarEmitterProvider.overrideWithValue(
          ScaffoldMessengerSummarizeEmitter(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
          ),
        ),
      ],
      child: const ManfredApp(),
    ),
  );
}

class ManfredApp extends StatelessWidget {
  const ManfredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manfred',
      debugShowCheckedModeBanner: false,
      theme: ManfredTheme.dark(),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: const AppInitGuard(),
    );
  }
}

class AppInitGuard extends ConsumerWidget {
  const AppInitGuard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userMeProvider);
    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        debugPrint('AppInitGuard error: $error\n$stackTrace');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Nie można połączyć się z serwerem.'),
                const SizedBox(height: 8),
                Text(
                  'Spróbuj ponownie za chwilę.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userMeProvider),
                  child: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          ),
        );
      },
      data: (_) => const ChatWorkspacePage(),
    );
  }
}
