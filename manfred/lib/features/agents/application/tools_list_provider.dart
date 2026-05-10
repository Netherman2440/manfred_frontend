import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tools_repository.dart';
import '../domain/tool_summary.dart';

/// Fetched once per app session; Riverpod caches the result.
final toolsListProvider = FutureProvider<List<ToolSummary>>((ref) {
  return ref.watch(toolsRepositoryProvider).listTools();
});
