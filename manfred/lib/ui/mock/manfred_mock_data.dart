import 'package:flutter/material.dart';

@immutable
class WorkspaceMock {
  const WorkspaceMock({
    required this.agents,
    required this.sessions,
    required this.sessionView,
    required this.rightRail,
  });

  final List<AgentMock> agents;
  final List<SessionMock> sessions;
  final SessionViewMock sessionView;
  final RightRailMock rightRail;
}

@immutable
class AgentMock {
  const AgentMock({
    required this.label,
    required this.name,
    required this.color,
    this.isActive = false,
  });

  final String label;
  final String name;
  final Color color;
  final bool isActive;
}

@immutable
class SessionMock {
  const SessionMock({
    required this.prefix,
    required this.title,
    this.isActive = false,
  });

  final String prefix;
  final String title;
  final bool isActive;
}

@immutable
class SessionViewMock {
  const SessionViewMock({
    required this.title,
    required this.rootAgent,
    required this.status,
    required this.entries,
  });

  final String title;
  final String rootAgent;
  final String status;
  final List<ConversationEntryMock> entries;
}

enum ConversationEntryType {
  userMessage,
  assistantMessage,
  toolCard,
  delegateThread,
}

@immutable
class ConversationEntryMock {
  const ConversationEntryMock({
    required this.type,
    required this.author,
    required this.dateLabel,
    required this.timeLabel,
    this.body,
    this.title,
    this.status,
    this.previewTitle,
    this.previewBody,
    this.tags = const <String>[],
    this.threadCount,
  });

  final ConversationEntryType type;
  final String author;
  final String dateLabel;
  final String timeLabel;
  final String? body;
  final String? title;
  final String? status;
  final String? previewTitle;
  final String? previewBody;
  final List<String> tags;
  final int? threadCount;
}

@immutable
class RightRailMock {
  const RightRailMock({required this.resources, required this.highlights});

  final List<RailResourceMock> resources;
  final List<RailHighlightMock> highlights;
}

@immutable
class RailResourceMock {
  const RailResourceMock({
    required this.title,
    required this.meta,
    required this.kind,
  });

  final String title;
  final String meta;
  final String kind;
}

@immutable
class RailHighlightMock {
  const RailHighlightMock({required this.label, required this.value});

  final String label;
  final String value;
}

final class ManfredMockData {
  const ManfredMockData._();

  static const workspace = WorkspaceMock(
    agents: <AgentMock>[
      AgentMock(
        label: 'MF',
        name: 'Manfred',
        color: Color(0xFF5EA1FF),
        isActive: true,
      ),
      AgentMock(label: 'PL', name: 'Planner', color: Color(0xFF76D39B)),
      AgentMock(label: 'FE', name: 'Frontend', color: Color(0xFFF5C271)),
      AgentMock(label: 'QA', name: 'Integrator', color: Color(0xFFF28A8A)),
    ],
    sessions: <SessionMock>[
      SessionMock(prefix: '#', title: 'ui-foundation', isActive: true),
      SessionMock(prefix: '#', title: 'streaming-states'),
      SessionMock(prefix: '#', title: 'delegate-preview'),
      SessionMock(prefix: '#', title: 'files-rail'),
      SessionMock(prefix: '#', title: 'agent-artifacts'),
      SessionMock(prefix: '#', title: 'design-notes'),
    ],
    sessionView: SessionViewMock(
      title: 'ui-foundation',
      rootAgent: 'Manfred',
      status: 'static mock',
      entries: <ConversationEntryMock>[
        ConversationEntryMock(
          type: ConversationEntryType.userMessage,
          author: 'NetHerman2440',
          dateLabel: '15.04.2026',
          timeLabel: '09:22',
          body:
              'Kolumna sesji ma być prostsza, bardziej jak lista kanałów. Dodatkowo ustawmy pełne koła dla ikon agentów i avatarów w czacie.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.assistantMessage,
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:23',
          body:
              'Upraszczam listę sesji do samych nazw z prefiksem, zaostrzam rogi przycisków przez wspólne tokeny stylu i zmieniam avatary na kołowe.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.toolCard,
          author: 'Tool',
          dateLabel: '15.04.2026',
          timeLabel: '09:24',
          title: 'update_theme_tokens',
          status: 'completed',
          body:
              'Zmieniono bazowe kolory aplikacji, hover tile wiadomości i styl panelu sesji.',
          previewTitle: 'manfred_theme.dart',
          previewBody:
              'appBackground=#0e0b09, sessionsBackground=#121214, hover=#222327, sharper button radius.',
          tags: <String>['theme', 'ui', 'hover'],
        ),
        ConversationEntryMock(
          type: ConversationEntryType.assistantMessage,
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:25',
          body:
              'Wiadomości użytkownika i agenta dostają hover na całym tile. Same karty tool i delegate zostają osobnymi blokami, żeby dalej odróżniały typy itemów.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.delegateThread,
          author: 'Frontend worker',
          dateLabel: '15.04.2026',
          timeLabel: '09:26',
          title: 'session-rail-refresh',
          body:
              'Przestawiono rail sesji na listę tekstową z aktywnym zaznaczeniem oraz kompaktowym layoutem mobilnym.',
          threadCount: 18,
          tags: <String>['frontend', 'sub-thread'],
        ),
      ],
    ),
    rightRail: RightRailMock(
      resources: <RailResourceMock>[
        RailResourceMock(
          title: 'ui-foundation.md',
          meta: 'spec / docs',
          kind: 'DOC',
        ),
        RailResourceMock(
          title: 'theme tokens',
          meta: 'bg, hover, radius',
          kind: 'STYLE',
        ),
        RailResourceMock(
          title: 'session-rail-refresh',
          meta: 'channel-like navigation',
          kind: 'THREAD',
        ),
      ],
      highlights: <RailHighlightMock>[
        RailHighlightMock(label: 'Root agent', value: 'Manfred'),
        RailHighlightMock(label: 'Session state', value: 'static mock'),
        RailHighlightMock(label: 'Visible items', value: '5'),
      ],
    ),
  );
}
