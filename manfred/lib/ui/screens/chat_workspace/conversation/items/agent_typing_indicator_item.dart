import 'package:flutter/material.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../theme/manfred_theme.dart';

class AgentTypingIndicatorItem extends StatefulWidget {
  const AgentTypingIndicatorItem({super.key, required this.author});

  final String author;

  @override
  State<AgentTypingIndicatorItem> createState() =>
      _AgentTypingIndicatorItemState();
}

class _AgentTypingIndicatorItemState extends State<AgentTypingIndicatorItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return HoverTileContainer(
      key: const ValueKey('agent-typing-indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AgentAvatar(
            label: _avatarLabel(widget.author),
            accentColor: ManfredColors.accentGreen,
          ),
          const SizedBox(width: 14),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                children: List<Widget>.generate(3, (index) {
                  final opacity = _dotOpacity(index);
                  return Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        '•',
                        style: textTheme.titleMedium?.copyWith(
                          color: ManfredColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  double _dotOpacity(int index) {
    final progress = (_controller.value + index * 0.2) % 1.0;
    if (progress < 0.33) {
      return 0.3 + progress * 1.7;
    }
    if (progress < 0.66) {
      return 0.86 - (progress - 0.33) * 0.6;
    }
    return 0.5 - (progress - 0.66) * 0.6;
  }

  String _avatarLabel(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }
}
