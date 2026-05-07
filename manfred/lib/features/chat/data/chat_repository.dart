import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/manfred_api_client.dart';
import '../../../core/api/sse_client.dart';
import '../../user/application/user_context_provider.dart';
import '../domain/chat_mutation_result.dart';
import '../domain/chat_stream_event.dart';
import '../domain/pending_attachment.dart';
import '../domain/queued_message.dart';
import 'chat_dto.dart';

abstract class ChatRepository {
  Future<ChatMutationResult> sendMessage({
    required String message,
    String? sessionId,
  });

  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  });
  Stream<ChatStreamEvent> deliverMessageStream({
    required String agentId,
    required String callId,
    required String message,
  });
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  });
  Future<ChatMutationResult> cancelRun({required String sessionId});
  Future<QueuedMessage> queueMessage({required QueuedMessage message});
  Stream<ChatStreamEvent> editMessageStream({
    required String sessionId,
    required String itemId,
    required String message,
    required List<String> retainAttachmentIds,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
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
    final payload = await _apiClient.postJson(
      '/chat/completions',
      body: _buildSendMessageBody(
        message: message,
        sessionId: sessionId,
        stream: false,
      ),
    );
    return ChatMutationResultDto.fromJson(payload).toDomain();
  }

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) async* {
    if (attachments.isEmpty) {
      yield* _streamRequest(
        '/chat/completions',
        body: _buildSendMessageBody(
          message: message,
          sessionId: sessionId,
          stream: true,
        ),
      );
      return;
    }

    final fields = <String, String>{'message': message, 'stream': 'true'};
    if (sessionId != null && sessionId.isNotEmpty) {
      fields['session_id'] = sessionId;
    }

    yield* _streamMultipartRequest(
      '/chat/completions',
      fields: fields,
      attachments: attachments,
    );
  }

  @override
  Stream<ChatStreamEvent> deliverMessageStream({
    required String agentId,
    required String callId,
    required String message,
  }) async* {
    final body = <String, Object?>{
      'call_id': callId,
      'output': message,
      'is_error': false,
      'stream': true,
    };

    yield* _streamRequest('/chat/agents/$agentId/deliver', body: body);
  }

  @override
  Future<ChatMutationResult> deliverMessage({
    required String agentId,
    required String callId,
    required String message,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[chat.deliver.request] agent_id=$agentId call_id=$callId output_length=${message.length}',
      );
    }
    final payload = await _apiClient.postJson(
      '/chat/agents/$agentId/deliver',
      body: <String, Object?>{
        'call_id': callId,
        'output': message,
        'is_error': false,
      },
    );
    if (kDebugMode) {
      debugPrint(
        '[chat.deliver.response] session_id=${payload['session_id'] ?? ''} agent_id=${payload['agent_id'] ?? ''} status=${payload['status'] ?? ''}',
      );
    }
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

  @override
  Future<QueuedMessage> queueMessage({required QueuedMessage message}) async {
    final path = '/chat/sessions/${message.sessionId}/queue';
    final payload = message.attachments.isEmpty
        ? await _apiClient.postJson(
            path,
            body: <String, Object?>{'message': message.message},
          )
        : await _apiClient.postMultipart(
            path,
            fields: <String, String>{'message': message.message},
            files: _toMultipartFiles(message.attachments),
          );
    return QueueMessageResultDto.fromJson(payload).applyTo(message);
  }

  @override
  Stream<ChatStreamEvent> editMessageStream({
    required String sessionId,
    required String itemId,
    required String message,
    required List<String> retainAttachmentIds,
    List<PendingAttachment> attachments = const <PendingAttachment>[],
  }) async* {
    final path = '/chat/sessions/$sessionId/items/$itemId';

    if (attachments.isEmpty) {
      yield* _streamRequest(
        path,
        method: 'PATCH',
        body: <String, Object?>{
          'message': message,
          'retain_attachment_ids': retainAttachmentIds,
          'stream': true,
        },
      );
      return;
    }

    yield* _streamMultipartRequest(
      path,
      method: 'PATCH',
      fields: <String, String>{'message': message, 'stream': 'true'},
      attachments: attachments,
      multiFields: retainAttachmentIds
          .map((id) => ('retain_attachment_ids', id))
          .toList(growable: false),
    );
  }

  Map<String, Object?> _buildSendMessageBody({
    required String message,
    required bool stream,
    String? sessionId,
  }) {
    final body = <String, Object?>{
      'input': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'message',
          'role': 'user',
          'content': message,
        },
      ],
      'stream': stream,
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }
    return body;
  }

  List<ApiMultipartFile> _toMultipartFiles(
    List<PendingAttachment> attachments,
  ) {
    return attachments
        .where((attachment) => !attachment.isExisting)
        .map(
          (attachment) => ApiMultipartFile(
            fieldName: 'attachments[]',
            fileName: attachment.fileName,
            mediaType: attachment.mediaType,
            bytes: attachment.bytes,
            filePath: attachment.localPath,
          ),
        )
        .toList(growable: false);
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

  void _logIncomingSseEvent({
    required SseMessage event,
    required Map<String, dynamic> payload,
  }) {
    if (!kDebugMode) {
      return;
    }

    final payloadPreview = payload.isEmpty ? event.data : jsonEncode(payload);
    debugPrint(
      '[chat.stream.raw] event=${event.event} id=${event.lastEventId ?? ''} retry_ms=${event.retryMs ?? ''} payload=${_truncateForLog(payloadPreview)}',
    );
  }

  void _logParsedChatStreamEvent({
    required String eventName,
    required String Function() details,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[chat.stream.parsed] event=$eventName ${details()}');
  }

  void _logIgnoredChatStreamEvent({
    required String eventName,
    required String reason,
    required Map<String, dynamic> payload,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[chat.stream.ignored] event=$eventName reason=$reason payload=${_truncateForLog(jsonEncode(payload))}',
    );
  }

  String _truncateForLog(String value, {int maxLength = 600}) {
    if (value.length <= maxLength) {
      return value;
    }

    return '${value.substring(0, maxLength)}...';
  }

  Stream<ChatStreamEvent> _streamMultipartRequest(
    String path, {
    String method = 'POST',
    required Map<String, String> fields,
    required List<PendingAttachment> attachments,
    List<(String, String)> multiFields = const <(String, String)>[],
  }) async* {
    final stream = switch (method) {
      'PATCH' => _apiClient.patchMultipartSse(
        path,
        fields: fields,
        files: _toMultipartFiles(attachments),
        multiFields: multiFields,
      ),
      _ => _apiClient.postMultipartSse(
        path,
        fields: fields,
        files: _toMultipartFiles(attachments),
      ),
    };

    await for (final event in stream) {
      final payload = _decodeEventPayload(event.data);
      _logIncomingSseEvent(event: event, payload: payload);
      yield* _mapStreamEvent(event: event, payload: payload);
    }
  }

  Stream<ChatStreamEvent> _streamRequest(
    String path, {
    String method = 'POST',
    required Map<String, Object?> body,
  }) async* {
    final stream = switch (method) {
      'PATCH' => _apiClient.patchSse(path, body: body),
      _ => _apiClient.postSse(path, body: body),
    };
    await for (final event in stream) {
      final payload = _decodeEventPayload(event.data);
      _logIncomingSseEvent(event: event, payload: payload);
      yield* _mapStreamEvent(event: event, payload: payload);
    }
  }

  Stream<ChatStreamEvent> _mapStreamEvent({
    required SseMessage event,
    required Map<String, dynamic> payload,
  }) async* {
    switch (event.event) {
      case 'session':
        final resolvedSessionId = payload['session_id'];
        final resolvedAgentId = payload['agent_id'];
        if (resolvedSessionId is String &&
            resolvedSessionId.isNotEmpty &&
            resolvedAgentId is String &&
            resolvedAgentId.isNotEmpty) {
          _logParsedChatStreamEvent(
            eventName: event.event,
            details: () =>
                'session_id=$resolvedSessionId agent_id=$resolvedAgentId',
          );
          yield ChatSessionStartedStreamEvent(
            sessionId: resolvedSessionId,
            agentId: resolvedAgentId,
          );
        } else {
          _logIgnoredChatStreamEvent(
            eventName: event.event,
            reason: 'missing session_id or agent_id',
            payload: payload,
          );
        }
        break;
      case 'text_delta':
        final delta = payload['delta'];
        if (delta is String && delta.isNotEmpty) {
          _logParsedChatStreamEvent(
            eventName: event.event,
            details: () => 'delta_length=${delta.length}',
          );
          yield ChatTextDeltaStreamEvent(delta: delta);
        } else {
          _logIgnoredChatStreamEvent(
            eventName: event.event,
            reason: 'missing delta',
            payload: payload,
          );
        }
        break;
      case 'text_done':
        final text = payload['text'];
        if (text is String && text.isNotEmpty) {
          _logParsedChatStreamEvent(
            eventName: event.event,
            details: () => 'text_length=${text.length}',
          );
          yield ChatTextDoneStreamEvent(text: text);
        } else {
          _logIgnoredChatStreamEvent(
            eventName: event.event,
            reason: 'missing text',
            payload: payload,
          );
        }
        break;
      case 'function_call_delta':
        final callId = payload['call_id'];
        final name = payload['name'];
        final argumentsDelta = payload['arguments_delta'];
        if (callId is String &&
            callId.isNotEmpty &&
            name is String &&
            name.isNotEmpty &&
            argumentsDelta is String &&
            argumentsDelta.isNotEmpty) {
          _logParsedChatStreamEvent(
            eventName: event.event,
            details: () =>
                'call_id=$callId name=$name delta_length=${argumentsDelta.length}',
          );
          yield ChatFunctionCallDeltaStreamEvent(
            callId: callId,
            name: name,
            argumentsDelta: argumentsDelta,
          );
        } else {
          _logIgnoredChatStreamEvent(
            eventName: event.event,
            reason: 'missing call_id, name or arguments_delta',
            payload: payload,
          );
        }
        break;
      case 'function_call_done':
        final callId = payload['call_id'];
        final name = payload['name'];
        if (callId is String &&
            callId.isNotEmpty &&
            name is String &&
            name.isNotEmpty) {
          _logParsedChatStreamEvent(
            eventName: event.event,
            details: () => 'call_id=$callId name=$name',
          );
          yield ChatFunctionCallDoneStreamEvent(
            callId: callId,
            name: name,
            arguments: payload['arguments'],
          );
        } else {
          _logIgnoredChatStreamEvent(
            eventName: event.event,
            reason: 'missing call_id or name',
            payload: payload,
          );
        }
        break;
      case 'done':
        _logParsedChatStreamEvent(
          eventName: event.event,
          details: () => 'done=true',
        );
        yield const ChatDoneStreamEvent();
        break;
      case 'error':
        final error = payload['error'];
        _logParsedChatStreamEvent(
          eventName: event.event,
          details: () => 'error=${error is String ? error : 'unknown'}',
        );
        yield ChatErrorStreamEvent(
          error: error is String && error.isNotEmpty
              ? error
              : 'Stream zakończony błędem.',
        );
        break;
      default:
        _logIgnoredChatStreamEvent(
          eventName: event.event,
          reason: 'unhandled event type',
          payload: payload,
        );
        break;
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return HttpChatRepository(apiClient: ref.watch(manfredApiClientProvider));
});
