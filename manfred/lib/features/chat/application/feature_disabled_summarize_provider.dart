import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session IDs for which the backend has reported 503 on `/summarize`.
///
/// In-memory only. A fresh app launch clears the set, letting the user
/// retry — the backend may have been re-enabled in the meantime.
final featureDisabledSummarizeProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);
