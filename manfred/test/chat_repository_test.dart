import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manfred/core/api/api_error.dart';
import 'package:manfred/core/api/manfred_api_client.dart';
import 'package:manfred/features/chat/data/chat_repository.dart';

void main() {
  test(
    'sendMessage omits session_id when there is no active session',
    () async {
      late Map<String, dynamic> requestBody;
      final client = MockClient((http.Request request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'session_id': 'session-created',
            'agent_id': 'agent-1',
            'status': 'completed',
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });

      final repository = HttpChatRepository(
        apiClient: ManfredApiClient(
          client: client,
          baseUrl: 'http://127.0.0.1:3000/api/v1',
        ),
      );

      await repository.sendMessage(message: 'hello');

      expect(requestBody.containsKey('session_id'), isFalse);
      expect(requestBody['stream'], isFalse);
    },
  );

  test('sendMessage includes session_id for existing session', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((http.Request request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'session_id': 'session-1',
          'agent_id': 'agent-1',
          'status': 'completed',
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final repository = HttpChatRepository(
      apiClient: ManfredApiClient(
        client: client,
        baseUrl: 'http://127.0.0.1:3000/api/v1',
      ),
    );

    await repository.sendMessage(message: 'hello', sessionId: 'session-1');

    expect(requestBody['session_id'], 'session-1');
  });

  test('postJson exposes HTTP status for non-JSON error responses', () async {
    final client = MockClient((http.Request request) async {
      return http.Response('Method Not Allowed', 405);
    });

    final apiClient = ManfredApiClient(
      client: client,
      baseUrl: 'http://127.0.0.1:3000/api/v1',
    );

    expect(
      () => apiClient.postJson(
        '/chat/completions',
        body: const <String, Object?>{'stream': false},
      ),
      throwsA(
        isA<ApiError>()
            .having((error) => error.statusCode, 'statusCode', 405)
            .having(
              (error) => error.message,
              'message',
              'Request failed (HTTP 405).',
            ),
      ),
    );
  });
}
