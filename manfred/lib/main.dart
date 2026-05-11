import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/user/application/user_me_provider.dart';
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
