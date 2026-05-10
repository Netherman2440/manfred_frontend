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
      error: (err, st) => const Text('Failed to load models'),
      data: (models) => _ModelPickerField(
        models: models,
        selectedModelId: selectedModelId,
        onChanged: onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable field — shows selected model, opens picker dialog on tap
// ---------------------------------------------------------------------------

class _ModelPickerField extends StatelessWidget {
  const _ModelPickerField({
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
    final selected = models.where((m) => m.id == selectedModelId).firstOrNull;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ManfredColors.panelAltBackground,
          borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
          border: Border.all(color: ManfredColors.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                selected?.displayName ?? 'Select model',
                style: textTheme.bodyMedium?.copyWith(
                  color: selected == null
                      ? ManfredColors.textMuted
                      : ManfredColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: ManfredColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _ModelPickerDialog(
        models: models,
        selectedModelId: selectedModelId,
      ),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

// ---------------------------------------------------------------------------
// Picker dialog with search
// ---------------------------------------------------------------------------

class _ModelPickerDialog extends StatefulWidget {
  const _ModelPickerDialog({
    required this.models,
    required this.selectedModelId,
  });

  final List<ModelSummary> models;
  final String? selectedModelId;

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ModelSummary> get _filtered {
    if (_query.isEmpty) return widget.models;
    final q = _query.toLowerCase();
    return widget.models
        .where(
          (m) =>
              m.displayName.toLowerCase().contains(q) ||
              m.id.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filtered;

    return Dialog(
      backgroundColor: ManfredColors.panelAltBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        side: const BorderSide(color: ManfredColors.borderSubtle),
      ),
      child: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header + search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search models...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: ManfredColors.textSecondary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ),

            // Divider
            const Divider(height: 1, color: ManfredColors.borderSubtle),

            // Model list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No models match "$_query"',
                        style: textTheme.bodyMedium?.copyWith(
                          color: ManfredColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final model = filtered[index];
                        final isSelected =
                            model.id == widget.selectedModelId;

                        return InkWell(
                          onTap: () => Navigator.pop(ctx, model.id),
                          child: Container(
                            color: isSelected
                                ? ManfredColors.accentBlue.withValues(
                                    alpha: 0.12,
                                  )
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    model.displayName,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? ManfredColors.accentBlue
                                          : ManfredColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: ManfredColors.accentBlue,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
