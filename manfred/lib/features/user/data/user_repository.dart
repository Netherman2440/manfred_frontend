import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../application/user_context_provider.dart';
import '../domain/user_me.dart';
import 'user_dto.dart';

class UserRepository {
  const UserRepository({required ManfredApiClient apiClient})
      : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  Future<UserMe> fetchMe() async {
    final payload = await _apiClient.getJson('/users/me');
    return UserMeResponseDto.fromJson(payload).toDomain();
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(apiClient: ref.watch(manfredApiClientProvider));
});
