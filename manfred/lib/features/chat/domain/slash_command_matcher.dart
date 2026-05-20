import 'slash_command.dart';
import 'slash_command_registry.dart';

/// Parses raw composer text into a slash-command query.
///
/// Returns `null` when the text (after trimming leading whitespace) does
/// not start with `/`. Returns the lowercase first token after the slash
/// — the empty string for a bare `/`, and everything up to the first
/// whitespace otherwise.
String? parseSlashQuery(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('/')) {
    return null;
  }
  final afterSlash = trimmed.substring(1);
  final firstToken = afterSlash.split(RegExp(r'\s+')).first;
  return firstToken.toLowerCase();
}

/// Returns the registry entries whose name starts with [query]
/// (case-insensitive). An empty query returns the full registry.
List<SlashCommand> filterCommands(
  String query, {
  List<SlashCommand> registry = slashCommandRegistry,
}) {
  final needle = query.toLowerCase();
  if (needle.isEmpty) {
    return List<SlashCommand>.of(registry);
  }
  return registry
      .where((cmd) => cmd.name.toLowerCase().startsWith(needle))
      .toList(growable: false);
}

/// Resolves [text] to a registered command iff the first whitespace-separated
/// token after `/` is an exact (case-insensitive) match for a command name.
///
/// Anything after the name (e.g. `/summarize foo bar`) is treated as ignored
/// arguments. Prefix-only matches (`/sum`) do NOT resolve — the user must
/// type the full name or accept from the palette.
SlashCommand? resolveCommand(
  String text, {
  List<SlashCommand> registry = slashCommandRegistry,
}) {
  final query = parseSlashQuery(text);
  if (query == null || query.isEmpty) {
    return null;
  }
  for (final cmd in registry) {
    if (cmd.name.toLowerCase() == query) {
      return cmd;
    }
  }
  return null;
}
