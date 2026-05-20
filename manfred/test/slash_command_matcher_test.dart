import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/chat/domain/slash_command.dart';
import 'package:manfred/features/chat/domain/slash_command_matcher.dart';
import 'package:manfred/features/chat/domain/slash_command_registry.dart';

void main() {
  group('parseSlashQuery', () {
    test('returns command name for "/summarize"', () {
      expect(parseSlashQuery('/summarize'), 'summarize');
    });

    test('lowercases the query', () {
      expect(parseSlashQuery('/SUMMARIZE'), 'summarize');
    });

    test('strips args after first whitespace', () {
      expect(parseSlashQuery('/summarize foo'), 'summarize');
    });

    test('trims leading whitespace before the slash', () {
      expect(parseSlashQuery('   /sum'), 'sum');
    });

    test('returns null for non-slash text', () {
      expect(parseSlashQuery('hi'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseSlashQuery(''), isNull);
    });

    test('returns empty string for bare slash', () {
      expect(parseSlashQuery('/'), '');
    });
  });

  group('filterCommands', () {
    test('empty query returns the full registry', () {
      final result = filterCommands('');
      expect(result, isNotEmpty);
      expect(result.any((c) => c.name == 'summarize'), isTrue);
      expect(result.length, slashCommandRegistry.length);
    });

    test('prefix match finds summarize', () {
      final result = filterCommands('sum');
      expect(result.any((c) => c.name == 'summarize'), isTrue);
    });

    test('match is case-insensitive', () {
      final result = filterCommands('SUM');
      expect(result.any((c) => c.name == 'summarize'), isTrue);
    });

    test('full name matches', () {
      final result = filterCommands('summarize');
      expect(result.any((c) => c.name == 'summarize'), isTrue);
    });

    test('non-matching query returns empty list', () {
      expect(filterCommands('xyz'), isEmpty);
    });

    test('honors injected registry', () {
      const customRegistry = <SlashCommand>[
        SlashCommand(name: 'apples', description: 'd1'),
        SlashCommand(name: 'apricots', description: 'd2'),
        SlashCommand(name: 'banana', description: 'd3'),
      ];
      final result = filterCommands('a', registry: customRegistry);
      expect(result, hasLength(2));
      expect(result.map((c) => c.name), containsAll(<String>['apples', 'apricots']));
    });
  });

  group('resolveCommand', () {
    test('exact "/summarize" resolves to summarize', () {
      final cmd = resolveCommand('/summarize');
      expect(cmd, isNotNull);
      expect(cmd!.name, 'summarize');
    });

    test('uppercase is accepted', () {
      final cmd = resolveCommand('/SUMMARIZE');
      expect(cmd?.name, 'summarize');
    });

    test('mixed case is accepted', () {
      final cmd = resolveCommand('/Summarize');
      expect(cmd?.name, 'summarize');
    });

    test('trailing space is accepted', () {
      final cmd = resolveCommand('/summarize ');
      expect(cmd?.name, 'summarize');
    });

    test('args after name are ignored', () {
      final cmd = resolveCommand('/summarize foo bar');
      expect(cmd?.name, 'summarize');
    });

    test('leading whitespace is trimmed', () {
      final cmd = resolveCommand('   /summarize');
      expect(cmd?.name, 'summarize');
    });

    test('prefix-only does not resolve', () {
      expect(resolveCommand('/sum'), isNull);
    });

    test('unknown command does not resolve', () {
      expect(resolveCommand('/unknown'), isNull);
    });

    test('no leading slash does not resolve', () {
      expect(resolveCommand('summarize'), isNull);
    });

    test('plain text does not resolve', () {
      expect(resolveCommand('plain text'), isNull);
    });

    test('empty string does not resolve', () {
      expect(resolveCommand(''), isNull);
    });
  });
}
