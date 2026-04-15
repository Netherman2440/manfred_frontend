import 'package:flutter/material.dart';

import '../../../mock/manfred_mock_data.dart';
import '../controls/composer_mock.dart';
import '../controls/workspace_icon_button.dart';
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
        Padding(
          padding: EdgeInsets.fromLTRB(
            showCompactHeader ? 16 : 24,
            18,
            showCompactHeader ? 16 : 24,
            16,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(sessionView.title, style: textTheme.titleLarge),
              ),
              WorkspaceIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Session options',
                onTap: () {},
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ConversationList(entries: sessionView.entries)),
        ComposerMock(showCompactLayout: showCompactHeader),
      ],
    );
  }
}
