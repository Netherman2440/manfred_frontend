import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/summarize_result.dart';

/// Delivers slash-command `/summarize` results to the UI.
///
/// Defined as an abstraction so the composer controller can be unit-tested
/// with a fake. The production implementation (a SnackBar widget) is wired
/// in T4 and overrides [summarizeSnackbarEmitterProvider] at the widget
/// tree root.
abstract class SummarizeSnackbarEmitter {
  void show(SummarizeResult result, {VoidCallback? onRetry});
}

final summarizeSnackbarEmitterProvider = Provider<SummarizeSnackbarEmitter>(
  (ref) => throw UnimplementedError(
    'Override summarizeSnackbarEmitterProvider at the app root ProviderScope.',
  ),
);
