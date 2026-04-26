import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/core/api/sse_client.dart';

void main() {
  const parser = SseMessageParser();

  test('parseLines buffers event and data fields into SSE messages', () {
    final messages = parser.parseLines(<String>[
      'event: text_delta',
      'data: {"delta":"Hello"}',
      'data: {"delta":" world"}',
      '',
      ':keep-alive',
      'data: {"type":"done"}',
      '',
    ]);

    expect(messages, hasLength(2));
    expect(messages[0].event, 'text_delta');
    expect(messages[0].data, '{"delta":"Hello"}\n{"delta":" world"}');
    expect(messages[1].event, 'message');
    expect(messages[1].data, '{"type":"done"}');
  });

  test('bind flushes a trailing message when the stream ends', () async {
    final controller = StreamController<String>();
    final messagesFuture = parser.bind(controller.stream).toList();

    controller
      ..add('event: text_delta')
      ..add('data: {"delta":"tail"}');
    await controller.close();

    final messages = await messagesFuture;

    expect(messages, hasLength(1));
    expect(messages.single.event, 'text_delta');
    expect(messages.single.data, '{"delta":"tail"}');
  });

  test('parseLines preserves id and retry metadata on dispatched messages', () {
    final messages = parser.parseLines(<String>[
      'id: evt-1',
      'retry: 2500',
      'event: text_delta',
      'data: {"delta":"Hello"}',
      '',
      'data: {"delta":"again"}',
      '',
    ]);

    expect(messages, hasLength(2));
    expect(messages[0].lastEventId, 'evt-1');
    expect(messages[0].retryMs, 2500);
    expect(messages[1].lastEventId, 'evt-1');
    expect(messages[1].retryMs, 2500);
  });
}
