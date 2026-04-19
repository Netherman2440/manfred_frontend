import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/chat_mutation_result.dart';
import 'chat_dto.dart';

abstract class ChatRepository {
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  });
}

class HttpChatRepository implements ChatRepository {
  HttpChatRepository({required ManfredApiClient apiClient})
    : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  @override
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    final body = <String, Object?>{
      'input': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'message',
          'role': 'user',
          'content': message,
        },
      ],
      'stream': false,
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }

    final payload = await _apiClient.postJson('/chat/completions', body: body);
    return ChatMutationResultDto.fromJson(payload).toDomain();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return HttpChatRepository(apiClient: ref.watch(manfredApiClientProvider));
});
