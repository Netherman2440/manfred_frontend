import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manfred/core/api/api_error.dart';
import 'package:manfred/core/api/manfred_api_client.dart';
import 'package:manfred/features/chat/data/chat_repository.dart';
import 'package:manfred/features/chat/domain/chat_stream_event.dart';

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

  test(
    'sendMessageStream posts stream=true and yields parsed text deltas',
    () async {
      late http.BaseRequest request;
      final client = _StreamingClient((incoming) async {
        request = incoming;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('event: text_delta\n'),
            utf8.encode('data: {"delta":"Cze"}\n\n'),
            utf8.encode('event: text_delta\n'),
            utf8.encode('data: {"delta":"ść"}\n\n'),
            utf8.encode('event: done\n'),
            utf8.encode('data: {"type":"done"}\n\n'),
          ]),
          200,
          headers: const <String, String>{'content-type': 'text/event-stream'},
        );
      });

      final repository = HttpChatRepository(
        apiClient: ManfredApiClient(
          client: client,
          baseUrl: 'http://127.0.0.1:3000/api/v1',
        ),
      );

      final events = await repository
          .sendMessageStream(message: 'hello', sessionId: 'session-1')
          .toList();

      expect(request.url.path, '/api/v1/chat/completions');
      expect(request.method, 'POST');
      expect(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>,
        <String, dynamic>{
          'input': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'message',
              'role': 'user',
              'content': 'hello',
            },
          ],
          'session_id': 'session-1',
          'stream': true,
        },
      );
      expect(events.length, 3);
      expect((events[0] as ChatTextDeltaStreamEvent).delta, 'Cze');
      expect((events[1] as ChatTextDeltaStreamEvent).delta, 'ść');
      expect(events[2], isA<ChatDoneStreamEvent>());
    },
  );

  test(
    'sendMessageStream parses function call and text completion events',
    () async {
      final client = _StreamingClient((incoming) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('event: function_call_delta\n'),
            utf8.encode(
              'data: {"call_id":"call-1","name":"calculator","arguments_delta":"{\\"a\\":"}\n\n',
            ),
            utf8.encode('event: function_call_done\n'),
            utf8.encode(
              'data: {"call_id":"call-1","name":"calculator","arguments":{"a":123}}\n\n',
            ),
            utf8.encode('event: text_done\n'),
            utf8.encode('data: {"text":"123 * 456 = 56088."}\n\n'),
          ]),
          200,
          headers: const <String, String>{'content-type': 'text/event-stream'},
        );
      });

      final repository = HttpChatRepository(
        apiClient: ManfredApiClient(
          client: client,
          baseUrl: 'http://127.0.0.1:3000/api/v1',
        ),
      );

      final events = await repository
          .sendMessageStream(message: 'hello')
          .toList();

      expect(events[0], isA<ChatFunctionCallDeltaStreamEvent>());
      expect(
        (events[0] as ChatFunctionCallDeltaStreamEvent).argumentsDelta,
        '{"a":',
      );
      expect(events[1], isA<ChatFunctionCallDoneStreamEvent>());
      expect(
        (events[1] as ChatFunctionCallDoneStreamEvent).arguments,
        <String, Object?>{'a': 123},
      );
      expect(events[2], isA<ChatTextDoneStreamEvent>());
      expect((events[2] as ChatTextDoneStreamEvent).text, '123 * 456 = 56088.');
    },
  );

  test(
    'sendMessageStream without session yields session bootstrap event',
    () async {
      late http.BaseRequest request;
      final client = _StreamingClient((incoming) async {
        request = incoming;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('event: session\n'),
            utf8.encode(
              'data: {"session_id":"session-created","agent_id":"agent-created"}\n\n',
            ),
            utf8.encode('event: done\n'),
            utf8.encode('data: {"type":"done"}\n\n'),
          ]),
          200,
          headers: const <String, String>{'content-type': 'text/event-stream'},
        );
      });

      final repository = HttpChatRepository(
        apiClient: ManfredApiClient(
          client: client,
          baseUrl: 'http://127.0.0.1:3000/api/v1',
        ),
      );

      final events = await repository
          .sendMessageStream(message: 'hello')
          .toList();

      final requestBody =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      expect(requestBody.containsKey('session_id'), isFalse);
      expect(events[0], isA<ChatSessionStartedStreamEvent>());
      expect(
        (events[0] as ChatSessionStartedStreamEvent).sessionId,
        'session-created',
      );
      expect(events[1], isA<ChatDoneStreamEvent>());
    },
  );
  test('deliverMessage posts agent delivery payload', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = MockClient((http.Request request) async {
      requestUri = request.url;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'session_id': 'session-1',
          'agent_id': 'agent-child',
          'status': 'waiting',
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

    await repository.deliverMessage(
      agentId: 'agent-child',
      callId: 'call-human',
      message: 'Chodzi o Zamek Królewski na Wawelu.',
    );

    expect(requestUri.path, '/api/v1/chat/agents/agent-child/deliver');
    expect(requestBody, <String, Object?>{
      'call_id': 'call-human',
      'output': 'Chodzi o Zamek Królewski na Wawelu.',
      'is_error': false,
    });
  });

  test(
    'deliverMessageStream posts stream=true and yields parsed text deltas',
    () async {
      late http.BaseRequest request;
      final client = _StreamingClient((incoming) async {
        request = incoming;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('event: text_delta\n'),
            utf8.encode('data: {"delta":"Dzię"}\n\n'),
            utf8.encode('event: text_done\n'),
            utf8.encode('data: {"text":"Dzięki."}\n\n'),
            utf8.encode('event: done\n'),
            utf8.encode('data: {"type":"done"}\n\n'),
          ]),
          200,
          headers: const <String, String>{'content-type': 'text/event-stream'},
        );
      });

      final repository = HttpChatRepository(
        apiClient: ManfredApiClient(
          client: client,
          baseUrl: 'http://127.0.0.1:3000/api/v1',
        ),
      );

      final events = await repository
          .deliverMessageStream(
            agentId: 'agent-child',
            callId: 'call-human',
            message: 'Chodzi o Zamek Królewski na Wawelu.',
          )
          .toList();

      expect(request.url.path, '/api/v1/chat/agents/agent-child/deliver');
      expect(request.method, 'POST');
      expect(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>,
        <String, dynamic>{
          'call_id': 'call-human',
          'output': 'Chodzi o Zamek Królewski na Wawelu.',
          'is_error': false,
          'stream': true,
        },
      );
      expect(events.length, 3);
      expect((events[0] as ChatTextDeltaStreamEvent).delta, 'Dzię');
      expect((events[1] as ChatTextDoneStreamEvent).text, 'Dzięki.');
      expect(events[2], isA<ChatDoneStreamEvent>());
    },
  );

  test('cancelRun posts session cancel payload', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = MockClient((http.Request request) async {
      requestUri = request.url;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'session_id': 'session-1',
          'agent_id': 'agent-1',
          'status': 'cancelled',
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

    final result = await repository.cancelRun(sessionId: 'session-1');

    expect(requestUri.path, '/api/v1/chat/sessions/session-1/cancel');
    expect(requestBody, isEmpty);
    expect(result.status, 'cancelled');
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

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}
