import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../controls/composer_mock.dart';
import '../conversation/conversation_list.dart';

class ConversationColumn extends StatelessWidget {
  const ConversationColumn({
    super.key,
    required this.sessionView,
    required this.showCompactHeader,
  });

  final SessionViewMock sessionView;
  final bool showCompactHeader;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        if (showCompactHeader) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(sessionView.title, style: textTheme.titleLarge),
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(child: ConversationList(entries: sessionView.entries)),
        ComposerMock(showCompactLayout: showCompactHeader),
      ],
    );
  }
}
