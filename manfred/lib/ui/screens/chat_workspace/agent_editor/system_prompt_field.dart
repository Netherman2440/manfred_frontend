import 'package:flutter/material.dart';

import '../../../theme/manfred_theme.dart';

class SystemPromptField extends StatelessWidget {
  const SystemPromptField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  static const int _maxLength = 20000;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TextField(
      controller: controller,
      maxLines: null,
      minLines: 8,
      maxLength: _maxLength,
      style: textTheme.bodyMedium?.copyWith(
        fontFamily: 'JetBrains Mono',
        color: ManfredColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'You are a helpful assistant...',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: ManfredColors.textMuted,
          fontFamily: 'JetBrains Mono',
        ),
        counterStyle: textTheme.labelSmall?.copyWith(
          color: ManfredColors.textMuted,
        ),
        alignLabelWithHint: true,
      ),
    );
  }
}
