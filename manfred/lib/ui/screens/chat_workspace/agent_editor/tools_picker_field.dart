import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/agents/application/tools_list_provider.dart';
import '../../../../features/agents/domain/tool_summary.dart';
import '../../../theme/manfred_theme.dart';

class ToolsPickerField extends ConsumerWidget {
  const ToolsPickerField({
    super.key,
    required this.selectedTools,
    required this.onChanged,
  });

  final Set<String> selectedTools;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(toolsListProvider);

    return toolsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const Text('Failed to load tools'),
      data: (tools) => _ToolsPickerContent(
        tools: tools,
        selectedTools: selectedTools,
        onChanged: onChanged,
      ),
    );
  }
}

class _ToolsPickerContent extends StatelessWidget {
  const _ToolsPickerContent({
    required this.tools,
    required this.selectedTools,
    required this.onChanged,
  });

  final List<ToolSummary> tools;
  final Set<String> selectedTools;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grouped = _groupByKind(tools);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final entry in grouped.entries) ...<Widget>[
          Text(
            _kindLabel(entry.key),
            style: textTheme.labelMedium?.copyWith(
              color: ManfredColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: entry.value.map((tool) {
              final isSelected = selectedTools.contains(tool.name);
              return Tooltip(
                message: tool.description ?? tool.name,
                child: FilterChip(
                  label: Text(tool.name),
                  selected: isSelected,
                  onSelected: (value) {
                    final updated = Set<String>.from(selectedTools);
                    if (value) {
                      updated.add(tool.name);
                    } else {
                      updated.remove(tool.name);
                    }
                    onChanged(updated);
                  },
                  backgroundColor: ManfredColors.panelAltBackground,
                  selectedColor:
                      ManfredColors.accentBlue.withValues(alpha: 0.2),
                  checkmarkColor: ManfredColors.accentBlue,
                  labelStyle: textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? ManfredColors.accentBlue
                        : ManfredColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? ManfredColors.accentBlue
                        : ManfredColors.borderSubtle,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Map<ToolKind, List<ToolSummary>> _groupByKind(List<ToolSummary> tools) {
    final result = <ToolKind, List<ToolSummary>>{};
    for (final tool in tools) {
      result.putIfAbsent(tool.kind, () => <ToolSummary>[]).add(tool);
    }
    return result;
  }

  String _kindLabel(ToolKind kind) {
    switch (kind) {
      case ToolKind.function:
        return 'Functions';
      case ToolKind.webSearch:
        return 'Web Search';
      case ToolKind.mcp:
        return 'MCP';
    }
  }
}
