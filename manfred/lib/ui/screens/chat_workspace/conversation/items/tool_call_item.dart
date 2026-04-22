import 'package:flutter/material.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';
import 'conversation_entry_header.dart';

class ToolCallItem extends StatefulWidget {
  const ToolCallItem({super.key, required this.entry});

  final ToolCallConversationEntryMock entry;

  @override
  State<ToolCallItem> createState() => _ToolCallItemState();
}

class _ToolCallItemState extends State<ToolCallItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;

    return HoverTileContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AgentAvatar(
            label: _avatarLabel(entry.author),
            accentColor: ManfredColors.accentGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConversationEntryHeader(
                  author: entry.author,
                  dateLabel: entry.dateLabel,
                  timeLabel: entry.timeLabel,
                  authorColor: ManfredColors.accentGreen,
                ),
                const SizedBox(height: 10),
                HoverTileContainer(
                  onTap: _toggleExpanded,
                  padding: const EdgeInsets.all(14),
                  baseColor: ManfredColors.panelAltBackground,
                  highlightColor: ManfredColors.messageHover,
                  borderRadius: ManfredShapes.panelRadius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _ToolBadge(toolName: entry.toolName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isExpanded
                                  ? 'Tool output and arguments'
                                  : 'Tool preview',
                              style: textTheme.labelSmall?.copyWith(
                                color: ManfredColors.textMuted,
                              ),
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            color: ManfredColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isExpanded)
                        _CodeBlock(
                          content: entry.argumentsPreview,
                          maxLines: 3,
                          dimmed: false,
                        ),
                      if (_isExpanded) ...<Widget>[
                        _JsonSection(
                          label: 'arguments',
                          content: entry.argumentsJson,
                        ),
                        const SizedBox(height: 10),
                        _JsonSection(
                          label: 'output',
                          content: _outputContent(entry),
                          isPlaceholder: entry.isOutputPending,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  String _avatarLabel(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }

  String _outputContent(ToolCallConversationEntryMock entry) {
    if (entry.isOutputPending) {
      return 'Pending response';
    }

    return entry.outputJson ?? entry.outputPreview ?? 'No output';
  }
}

class _ToolBadge extends StatelessWidget {
  const _ToolBadge({required this.toolName});

  final String toolName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ManfredColors.panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ManfredColors.borderStrong),
      ),
      child: Text(
        toolName,
        style: textTheme.labelLarge?.copyWith(color: ManfredColors.accentBlue),
      ),
    );
  }
}

class _JsonSection extends StatelessWidget {
  const _JsonSection({
    required this.label,
    required this.content,
    this.isPlaceholder = false,
  });

  final String label;
  final String content;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: ManfredColors.textMuted),
        ),
        const SizedBox(height: 6),
        _CodeBlock(content: content, dimmed: isPlaceholder),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.content, this.dimmed = false, this.maxLines});

  final String content;
  final bool dimmed;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ManfredColors.panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: SelectableText(
        content,
        maxLines: maxLines,
        style: textTheme.bodySmall?.copyWith(
          color: dimmed ? ManfredColors.textMuted : ManfredColors.textPrimary,
          height: 1.45,
        ),
      ),
    );
  }
}
