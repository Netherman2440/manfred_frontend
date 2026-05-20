import 'slash_command.dart';

const List<SlashCommand> slashCommandRegistry = <SlashCommand>[
  SlashCommand(
    name: 'summarize',
    description: 'Fold the current conversation into long-term observations.',
  ),
];
