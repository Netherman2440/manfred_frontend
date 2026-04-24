class SseMessage {
  const SseMessage({required this.event, required this.data});

  final String event;
  final String data;
}

class SseMessageParser {
  const SseMessageParser();

  List<SseMessage> parseLines(Iterable<String> lines) {
    final messages = <SseMessage>[];
    String? eventName;
    final dataLines = <String>[];

    void flush() {
      if (eventName == null && dataLines.isEmpty) {
        return;
      }

      messages.add(
        SseMessage(event: eventName ?? 'message', data: dataLines.join('\n')),
      );
      eventName = null;
      dataLines.clear();
    }

    for (final line in lines) {
      if (line.isEmpty) {
        flush();
        continue;
      }

      if (line.startsWith(':')) {
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final field = separatorIndex == -1
          ? line
          : line.substring(0, separatorIndex);
      var value = separatorIndex == -1
          ? ''
          : line.substring(separatorIndex + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          dataLines.add(value);
      }
    }

    flush();
    return messages;
  }
}
