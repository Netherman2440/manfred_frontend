import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import '../domain/user_me.dart';

final userMeProvider = FutureProvider<UserMe>((ref) async {
  return ref.watch(userRepositoryProvider).fetchMe();
});
