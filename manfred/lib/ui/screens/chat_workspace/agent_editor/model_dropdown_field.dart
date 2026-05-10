import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/agents/application/models_list_provider.dart';
import '../../../../features/agents/domain/model_summary.dart';
import '../../../theme/manfred_theme.dart';

class ModelDropdownField extends ConsumerWidget {
  const ModelDropdownField({
    super.key,
    required this.selectedModelId,
    required this.onChanged,
  });

  final String? selectedModelId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsListProvider);

    return modelsAsync.when(
      loading: () => Container(
        height: 52,
        decoration: BoxDecoration(
          color: ManfredColors.panelAltBackground,
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          border: Border.all(color: ManfredColors.borderSubtle),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => const Text('Failed to load models'),
      data: (models) => _ModelDropdown(
        models: models,
        selectedModelId: selectedModelId,
        onChanged: onChanged,
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.models,
    required this.selectedModelId,
    required this.onChanged,
  });

  final List<ModelSummary> models;
  final String? selectedModelId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Guard: if the saved model id is not present in the list, fall back to
    // null so DropdownButtonFormField doesn't throw an assertion error.
    final effectiveValue =
        models.any((m) => m.id == selectedModelId) ? selectedModelId : null;

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      dropdownColor: ManfredColors.panelAltBackground,
      decoration: InputDecoration(
        hintText: 'Select model',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: ManfredColors.textMuted,
        ),
      ),
      items: models.map((model) {
        return DropdownMenuItem<String>(
          value: model.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                model.displayName,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (model.contextLength != null)
                Text(
                  '${_formatContextLength(model.contextLength!)} ctx',
                  style: textTheme.labelSmall?.copyWith(
                    color: ManfredColors.textMuted,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _formatContextLength(int length) {
    if (length >= 1000) {
      return '${(length / 1000).toStringAsFixed(0)}k';
    }
    return length.toString();
  }
}
