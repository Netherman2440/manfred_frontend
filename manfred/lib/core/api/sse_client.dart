import 'dart:async';

class SseMessage {
  const SseMessage({
    required this.event,
    required this.data,
    this.lastEventId,
    this.retryMs,
  });

  final String event;
  final String data;
  final String? lastEventId;
  final int? retryMs;
}

class SseMessageParser {
  const SseMessageParser();

  List<SseMessage> parseLines(Iterable<String> lines) {
    final accumulator = _SseMessageAccumulator();
    final messages = <SseMessage>[];

    for (final line in lines) {
      final message = accumulator.addLine(line);
      if (message != null) {
        messages.add(message);
      }
    }

    final trailingMessage = accumulator.flush();
    if (trailingMessage != null) {
      messages.add(trailingMessage);
    }
    return messages;
  }

  Stream<SseMessage> bind(Stream<String> lines) async* {
    final accumulator = _SseMessageAccumulator();

    await for (final line in lines) {
      final message = accumulator.addLine(line);
      if (message != null) {
        yield message;
      }
    }

    final trailingMessage = accumulator.flush();
    if (trailingMessage != null) {
      yield trailingMessage;
    }
  }
}

class _SseMessageAccumulator {
  String? _eventName;
  String? _lastEventId;
  int? _retryMs;
  final List<String> _dataLines = <String>[];

  SseMessage? addLine(String line) {
    if (line.isEmpty) {
      return flush();
    }

    if (line.startsWith(':')) {
      return null;
    }

    final separatorIndex = line.indexOf(':');
    final field = separatorIndex == -1
        ? line
        : line.substring(0, separatorIndex);
    var value = separatorIndex == -1 ? '' : line.substring(separatorIndex + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    if (field == 'event') {
      _eventName = value;
      return null;
    }

    if (field == 'id') {
      _lastEventId = value;
      return null;
    }

    if (field == 'retry') {
      final retryMs = int.tryParse(value);
      if (retryMs != null) {
        _retryMs = retryMs;
      }
      return null;
    }

    if (field == 'data') {
      _dataLines.add(value);
    }

    return null;
  }

  SseMessage? flush() {
    if (_eventName == null && _dataLines.isEmpty) {
      return null;
    }

    final message = SseMessage(
      event: _eventName ?? 'message',
      data: _dataLines.join('\n'),
      lastEventId: _lastEventId,
      retryMs: _retryMs,
    );
    _eventName = null;
    _dataLines.clear();
    return message;
  }
}
