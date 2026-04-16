import 'package:flutter/material.dart';

class ConversationEntryHeader extends StatelessWidget {
  const ConversationEntryHeader({
    super.key,
    required this.author,
    required this.dateLabel,
    required this.timeLabel,
    required this.authorColor,
  });

  final String author;
  final String dateLabel;
  final String timeLabel;
  final Color authorColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(author, style: textTheme.labelLarge?.copyWith(color: authorColor)),
        Text('$dateLabel $timeLabel', style: textTheme.labelSmall),
      ],
    );
  }
}
