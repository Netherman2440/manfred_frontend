import 'package:flutter/material.dart';

import '../../../../features/chat/domain/slash_command.dart';
import '../../../theme/manfred_fonts.dart';
import '../../../theme/manfred_theme.dart';

/// Floating slash-command palette rendered just above the composer input.
///
/// Owns its own selection state and accepts the filtered command list +
/// the current query. Selection clamps to bounds on every rebuild so a
/// shrinking list never leaves the index dangling.
class SlashCommandPalette extends StatefulWidget {
  const SlashCommandPalette({
    super.key,
    required this.commands,
    required this.query,
    required this.onCommandSelected,
  });

  /// Commands matching the current query, in registry order.
  final List<SlashCommand> commands;

  /// Lowercased query (everything after the first `/`, up to first whitespace).
  final String query;

  /// Invoked when the user picks a command via tap.
  /// Enter handling is owned by the parent composer (it knows whether the
  /// draft is an exact match).
  final ValueChanged<SlashCommand> onCommandSelected;

  @override
  State<SlashCommandPalette> createState() => SlashCommandPaletteState();
}

class SlashCommandPaletteState extends State<SlashCommandPalette> {
  int _selectedIndex = 0;

  /// Read-only accessor for the parent (so Enter can match selection ↔ draft).
  SlashCommand? get selectedCommand {
    if (widget.commands.isEmpty) {
      return null;
    }
    final clamped = _selectedIndex.clamp(0, widget.commands.length - 1);
    return widget.commands[clamped];
  }

  void moveSelectionUp() {
    if (widget.commands.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex - 1).clamp(0, widget.commands.length - 1);
    });
  }

  void moveSelectionDown() {
    if (widget.commands.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + 1).clamp(0, widget.commands.length - 1);
    });
  }

  @override
  void didUpdateWidget(SlashCommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-clamp selection when the filtered list shrinks beneath the index.
    if (widget.commands.isNotEmpty &&
        _selectedIndex >= widget.commands.length) {
      _selectedIndex = widget.commands.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final commands = widget.commands;
    final monoHeader = ManfredFonts.mono(
      const TextStyle(
        fontSize: 10,
        height: 1.2,
        color: ManfredColors.textMuted,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w500,
      ),
    );
    final matchCounterStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 10,
        color: ManfredColors.borderStrong,
        letterSpacing: 1.2,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ManfredColors.panelOverlay,
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              children: <Widget>[
                Text('COMMANDS', style: monoHeader),
                const Spacer(),
                Text(
                  commands.isEmpty
                      ? '0 match'
                      : '${commands.length} '
                          '${commands.length == 1 ? 'match' : 'matches'}',
                  style: matchCounterStyle,
                ),
              ],
            ),
          ),
          Container(height: 1, color: ManfredColors.borderSubtle),
          // List
          if (commands.isEmpty)
            const _EmptyStateRow()
          else
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < commands.length; i++)
                    _SlashCommandItem(
                      command: commands[i],
                      isSelected: i == _selectedIndex,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        widget.onCommandSelected(commands[i]);
                      },
                      onHover: (hovering) {
                        if (hovering) {
                          setState(() => _selectedIndex = i);
                        }
                      },
                    ),
                ],
              ),
            ),
          // Footer
          Container(height: 1, color: ManfredColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: <Widget>[
                const _FooterHint(keys: <String>['↑', '↓'], label: 'navigate'),
                const SizedBox(width: 18),
                const _FooterHint(keys: <String>['↵'], label: 'run'),
                const SizedBox(width: 18),
                const _FooterHint(keys: <String>['esc'], label: 'close'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlashCommandItem extends StatelessWidget {
  const _SlashCommandItem({
    required this.command,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  final SlashCommand command;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final nameStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: ManfredColors.textPrimary,
        letterSpacing: 0.1,
      ),
    );
    final slashStyle = nameStyle.copyWith(color: ManfredColors.accentBlue);
    final descStyle = ManfredFonts.sans(
      const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: ManfredColors.textSecondary,
      ),
    );
    final shortcutStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 10,
        color: ManfredColors.textMuted,
        letterSpacing: 0.6,
      ),
    );

    return MouseRegion(
      onEnter: (_) => onHover(true),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? ManfredColors.accentBlueSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? ManfredColors.accentBlue
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              // Name column
              RichText(
                text: TextSpan(
                  children: <TextSpan>[
                    TextSpan(text: '/', style: slashStyle),
                    TextSpan(text: command.name, style: nameStyle),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  command.description,
                  style: descStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 14),
              Text(isSelected ? '↵' : '↑↓', style: shortcutStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateRow extends StatelessWidget {
  const _EmptyStateRow();

  @override
  Widget build(BuildContext context) {
    final style = ManfredFonts.sans(
      const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: ManfredColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Text('No matching commands', style: style),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.keys, required this.label});

  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 10,
        color: ManfredColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
    final kbdStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 9,
        color: ManfredColors.textSecondary,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final key in keys) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: ManfredColors.panelAltBackground,
              borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
              border: Border.all(color: ManfredColors.borderSubtle),
            ),
            child: Text(key, style: kbdStyle),
          ),
        ],
        const SizedBox(width: 2),
        Text(label, style: labelStyle),
      ],
    );
  }
}
