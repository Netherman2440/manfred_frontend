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
                          Expanded(
                            child: Text(
                              entry.toolName,
                              style: textTheme.titleSmall?.copyWith(
                                color: ManfredColors.accentBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            color: ManfredColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.argumentsPreview,
                        maxLines: _isExpanded ? null : 1,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: ManfredColors.textSecondary,
                        ),
                      ),
                      if (_isExpanded) ...<Widget>[
                        const SizedBox(height: 14),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ManfredColors.panelRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ManfredColors.borderSubtle),
          ),
          child: Text(
            content,
            style: textTheme.bodySmall?.copyWith(
              color: isPlaceholder
                  ? ManfredColors.textMuted
                  : ManfredColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
