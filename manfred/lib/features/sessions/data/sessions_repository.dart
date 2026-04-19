import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/session_details.dart';
import '../domain/session_list_entry.dart';
import 'sessions_dto.dart';

abstract class SessionsRepository {
  Future<List<SessionListEntry>> fetchSessions(String userId);

  Future<SessionDetails> fetchSessionDetails(String userId, String sessionId);
}

class HttpSessionsRepository implements SessionsRepository {
  HttpSessionsRepository({required ManfredApiClient apiClient})
    : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  @override
  Future<List<SessionListEntry>> fetchSessions(String userId) async {
    final payload = await _apiClient.getJson('/users/$userId/sessions');
    return SessionsListResponseDto.fromJson(
      payload,
    ).data.map((item) => item.toDomain()).toList(growable: false);
  }

  @override
  Future<SessionDetails> fetchSessionDetails(
    String userId,
    String sessionId,
  ) async {
    final payload = await _apiClient.getJson(
      '/users/$userId/sessions/$sessionId',
    );
    return SessionDetailsResponseDto.fromJson(payload).data.toDomain();
  }
}

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return HttpSessionsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
