import 'package:flutter/material.dart';

import '../../../../core/hover_tile_container.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';

class AgentThreadItem extends StatelessWidget {
  const AgentThreadItem({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.onTap,
  });

  final AgentThreadConversationEntryMock entry;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ThreadStartRail(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText.rich(
                  TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: ManfredColors.textSecondary,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Agent '),
                      TextSpan(
                        text: entry.agentName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: ManfredColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' rozpoczął wątek: '),
                      TextSpan(
                        text: entry.taskPreview,
                        style: textTheme.bodyMedium?.copyWith(
                          color: ManfredColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.dateLabel}, ${entry.timeLabel}',
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: 12),
                HoverTileContainer(
                  onTap: onTap,
                  baseColor: isSelected
                      ? ManfredColors.panelOverlay
                      : ManfredColors.panelAltBackground,
                  highlightColor: ManfredColors.messageHover,
                  borderRadius: ManfredShapes.panelRadius,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        ManfredShapes.panelRadius,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? ManfredColors.accentBlue
                            : ManfredColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Text(
                                    entry.threadTitle,
                                    style: textTheme.titleSmall?.copyWith(
                                      color: ManfredColors.accentBlue,
                                    ),
                                  ),
                                  Text(
                                    entry.threadMeta,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: ManfredColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                entry.statusLabel,
                                style: textTheme.bodySmall?.copyWith(
                                  color: ManfredColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isSelected
                              ? Icons.keyboard_arrow_left_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          color: isSelected
                              ? ManfredColors.accentBlue
                              : ManfredColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadStartRail extends StatelessWidget {
  const _ThreadStartRail();

  static const double _leadingSize = 42;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _leadingSize,
      child: Column(
        children: const <Widget>[
          Align(child: _ThreadStartBadge()),
          SizedBox(height: 8),
          _ThreadConnector(),
        ],
      ),
    );
  }
}

class _ThreadStartBadge extends StatelessWidget {
  const _ThreadStartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: ManfredColors.panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: const Icon(
        Icons.call_split_rounded,
        size: 15,
        color: ManfredColors.textMuted,
      ),
    );
  }
}

class _ThreadConnector extends StatelessWidget {
  const _ThreadConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ThreadStartRail._leadingSize,
      height: 74,
      child: Align(
        child: SizedBox(
          width: 24,
          height: 74,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: ManfredColors.borderStrong),
                bottom: BorderSide(color: ManfredColors.borderStrong),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
