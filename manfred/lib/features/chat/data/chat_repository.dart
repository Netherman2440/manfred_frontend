import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
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

  @override
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  }) async {
    debugPrint(
      '[chat.deliver.request] agent_id=$agentId call_id=$callId message=${jsonEncode(message)}',
    );
    final payload = await _apiClient.postJson(
      '/chat/agents/$agentId/deliver',
      body: <String, Object?>{
        'call_id': callId,
        'output': message,
        'is_error': false,
      },
    );
    debugPrint('[chat.deliver.response] ${jsonEncode(payload)}');
    return ChatMutationResultDto.fromJson(payload).toDomain();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return HttpChatRepository(apiClient: ref.watch(manfredApiClientProvider));
});
