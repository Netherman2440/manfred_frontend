import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';

const List<Color> kAgentPalette = <Color>[
  Color(0xFF5EA1FF),
  Color(0xFF76D39B),
  Color(0xFFF5C271),
  Color(0xFFF28A8A),
  Color(0xFFB68AF2),
  Color(0xFF6BD4DA),
  Color(0xFFE0A0F0),
  Color(0xFF9DA5B4),
];

class ColorPickerField extends StatelessWidget {
  const ColorPickerField({
    super.key,
    required this.agentName,
    required this.selectedColor,
    required this.onColorChanged,
  });

  final String agentName;
  final Color? selectedColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayColor =
        selectedColor ?? ManfredColors.panelAltBackground;

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.18),
              borderRadius:
                  BorderRadius.circular(ManfredShapes.inputRadius),
              border: Border.all(color: ManfredColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                agentName.isEmpty ? 'Agent Name' : agentName,
                style: textTheme.titleSmall?.copyWith(
                  color: selectedColor ?? ManfredColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showColorPicker(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selectedColor ?? ManfredColors.panelAltBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ManfredColors.borderStrong),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPaletteDialog(
        selectedColor: selectedColor,
        onColorSelected: (color) => Navigator.pop(ctx, color),
      ),
    );
    if (picked != null) {
      onColorChanged(picked);
    }
  }
}

class ColorPaletteDialog extends StatelessWidget {
  const ColorPaletteDialog({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ManfredColors.panelAltBackground,
      title: const Text('Choose color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: kAgentPalette.map((color) {
          final isSelected = selectedColor == color;
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
