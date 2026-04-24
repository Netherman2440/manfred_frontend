import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/chat_mutation_result.dart';
import '../domain/chat_stream_event.dart';
import 'chat_dto.dart';

abstract class ChatRepository {
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  });

  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
  });
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  });
  Future<ChatMutationResult> cancelRun({required String sessionId});
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
  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
  }) async* {
    final body = <String, Object?>{
      'input': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'message',
          'role': 'user',
          'content': message,
        },
      ],
      'stream': true,
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }

    await for (final event in _apiClient.postSse(
      '/chat/completions',
      body: body,
    )) {
      final payload = _decodeEventPayload(event.data);
      switch (event.event) {
        case 'session':
          final resolvedSessionId = payload['session_id'];
          final resolvedAgentId = payload['agent_id'];
          if (resolvedSessionId is String &&
              resolvedSessionId.isNotEmpty &&
              resolvedAgentId is String &&
              resolvedAgentId.isNotEmpty) {
            yield ChatSessionStartedStreamEvent(
              sessionId: resolvedSessionId,
              agentId: resolvedAgentId,
            );
          }
          break;
        case 'text_delta':
          final delta = payload['delta'];
          if (delta is String && delta.isNotEmpty) {
            yield ChatTextDeltaStreamEvent(delta: delta);
          }
          break;
        case 'done':
          yield const ChatDoneStreamEvent();
          break;
        case 'error':
          final error = payload['error'];
          yield ChatErrorStreamEvent(
            error: error is String && error.isNotEmpty
                ? error
                : 'Stream zakończony błędem.',
          );
          break;
        default:
          continue;
      }
    }
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

  @override
  Future<ChatMutationResult> cancelRun({required String sessionId}) async {
    final payload = await _apiClient.postJson(
      '/chat/sessions/$sessionId/cancel',
      body: const <String, Object?>{},
    );
    return ChatMutationResultDto.fromJson(payload).toDomain();
  }

  Map<String, dynamic> _decodeEventPayload(String rawPayload) {
    if (rawPayload.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      debugPrint('[chat.stream.payload.invalid] payload=$rawPayload');
    }

    return const <String, dynamic>{};
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return HttpChatRepository(apiClient: ref.watch(manfredApiClientProvider));
});
