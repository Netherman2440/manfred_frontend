import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models_repository.dart';
import '../domain/model_summary.dart';

/// Fetched once per app session; backend TTL is ~1 hour.
final modelsListProvider = FutureProvider<List<ModelSummary>>((ref) {
  return ref.watch(modelsRepositoryProvider).listModels();
});
