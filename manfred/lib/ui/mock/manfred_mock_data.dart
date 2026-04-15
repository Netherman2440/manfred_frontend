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
    required this.entries,
  });

  final String title;
  final String rootAgent;
  final List<ConversationEntryMock> entries;
}

enum ConversationEntryType { user, agent }

@immutable
class ConversationEntryMock {
  const ConversationEntryMock({
    required this.type,
    required this.author,
    required this.dateLabel,
    required this.timeLabel,
    required this.body,
  });

  final ConversationEntryType type;
  final String author;
  final String dateLabel;
  final String timeLabel;
  final String body;
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
      entries: <ConversationEntryMock>[
        ConversationEntryMock(
          type: ConversationEntryType.user,
          author: 'NetHerman2440',
          dateLabel: '15.04.2026',
          timeLabel: '09:22',
          body:
              'Kolumna sesji ma być prostsza, bardziej jak lista kanałów. Dodatkowo ustawmy pełne koła dla ikon agentów i avatarów w czacie.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.agent,
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:23',
          body:
              'Upraszczam listę sesji do samych nazw z prefiksem, zaostrzam rogi przycisków przez wspólne tokeny stylu i zmieniam avatary na kołowe.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.agent,
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:24',
          body:
              'Wydzielam wspólne prymitywy UI do osobnych plików, żeby hover, avatary i tła kolumn nie były już kopiowane po ekranie.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.user,
          author: 'NetHerman2440',
          dateLabel: '15.04.2026',
          timeLabel: '09:25',
          body:
              'Dobrze. Kolumny mają być w osobnych plikach, a sama konwersacja nie ma już rozróżniać tooli ani delegate.',
        ),
        ConversationEntryMock(
          type: ConversationEntryType.agent,
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:26',
          body:
              'Jasne. Rozbijam workspace na kolumny, dodaję wspólny hover container i upraszczam model wiadomości do dwóch typów: user oraz agent.',
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
          title: 'workspace-columns',
          meta: 'chat workspace split',
          kind: 'REF',
        ),
      ],
      highlights: <RailHighlightMock>[
        RailHighlightMock(label: 'Root agent', value: 'Manfred'),
        RailHighlightMock(label: 'Session state', value: 'refactor draft'),
        RailHighlightMock(label: 'Visible items', value: '5'),
      ],
    ),
  );
}
