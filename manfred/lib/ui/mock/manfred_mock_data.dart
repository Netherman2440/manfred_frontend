import 'package:flutter/material.dart';

@immutable
class WorkspaceMock {
  const WorkspaceMock({
    required this.agents,
    required this.sessions,
    required this.sessionView,
    required this.rightRail,
    required this.currentUser,
  });

  final List<AgentMock> agents;
  final List<SessionMock> sessions;
  final SessionViewMock sessionView;
  final RightRailMock rightRail;
  final CurrentUserMock currentUser;

  WorkspaceMock copyWith({
    List<AgentMock>? agents,
    List<SessionMock>? sessions,
    SessionViewMock? sessionView,
    RightRailMock? rightRail,
    CurrentUserMock? currentUser,
  }) {
    return WorkspaceMock(
      agents: agents ?? this.agents,
      sessions: sessions ?? this.sessions,
      sessionView: sessionView ?? this.sessionView,
      rightRail: rightRail ?? this.rightRail,
      currentUser: currentUser ?? this.currentUser,
    );
  }
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
    required this.id,
    required this.prefix,
    required this.title,
    this.isActive = false,
  });

  final String id;
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
    this.threads = const <ConversationThreadMock>[],
  });

  final String title;
  final String rootAgent;
  final List<ConversationEntryMock> entries;
  final List<ConversationThreadMock> threads;

  SessionViewMock copyWith({
    String? title,
    String? rootAgent,
    List<ConversationEntryMock>? entries,
    List<ConversationThreadMock>? threads,
  }) {
    return SessionViewMock(
      title: title ?? this.title,
      rootAgent: rootAgent ?? this.rootAgent,
      entries: entries ?? this.entries,
      threads: threads ?? this.threads,
    );
  }
}

@immutable
class ConversationThreadMock {
  const ConversationThreadMock({
    required this.id,
    required this.agentName,
    required this.title,
    required this.task,
    required this.statusLabel,
    required this.entries,
    this.metaLabel,
    this.placeholderLabel,
  });

  final String id;
  final String agentName;
  final String title;
  final String task;
  final String statusLabel;
  final List<ConversationEntryMock> entries;
  final String? metaLabel;
  final String? placeholderLabel;
}

@immutable
sealed class ConversationEntryMock {
  const ConversationEntryMock({
    required this.dateLabel,
    required this.timeLabel,
  });

  final String dateLabel;
  final String timeLabel;
}

@immutable
class UserConversationEntryMock extends ConversationEntryMock {
  const UserConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.body,
  });

  final String author;
  final String body;
}

@immutable
class AgentConversationEntryMock extends ConversationEntryMock {
  const AgentConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.body,
  });

  final String author;
  final String body;
}

@immutable
class ToolCallConversationEntryMock extends ConversationEntryMock {
  const ToolCallConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.toolName,
    required this.argumentsPreview,
    required this.argumentsJson,
    this.outputPreview,
    this.outputJson,
    this.isOutputPending = false,
  });

  final String author;
  final String toolName;
  final String argumentsPreview;
  final String argumentsJson;
  final String? outputPreview;
  final String? outputJson;
  final bool isOutputPending;
}

@immutable
class AgentPingConversationEntryMock extends ConversationEntryMock {
  const AgentPingConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.agentName,
    required this.task,
  });

  final String author;
  final String agentName;
  final String task;
}

@immutable
class UserPingConversationEntryMock extends ConversationEntryMock {
  const UserPingConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.userName,
    required this.task,
  });

  final String author;
  final String userName;
  final String task;
}

@immutable
class AgentThreadConversationEntryMock extends ConversationEntryMock {
  const AgentThreadConversationEntryMock({
    required super.dateLabel,
    required super.timeLabel,
    required this.author,
    required this.threadId,
    required this.agentName,
    required this.taskPreview,
    required this.threadTitle,
    required this.threadMeta,
    required this.statusLabel,
  });

  final String author;
  final String threadId;
  final String agentName;
  final String taskPreview;
  final String threadTitle;
  final String threadMeta;
  final String statusLabel;
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

@immutable
class CurrentUserMock {
  const CurrentUserMock({
    required this.label,
    required this.name,
    required this.status,
    required this.color,
  });

  final String label;
  final String name;
  final String status;
  final Color color;
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
      SessionMock(
        id: 'ui-foundation',
        prefix: '#',
        title: 'ui-foundation',
        isActive: true,
      ),
      SessionMock(
        id: 'streaming-states',
        prefix: '#',
        title: 'streaming-states',
      ),
      SessionMock(
        id: 'delegate-preview',
        prefix: '#',
        title: 'delegate-preview',
      ),
      SessionMock(id: 'files-rail', prefix: '#', title: 'files-rail'),
      SessionMock(id: 'agent-artifacts', prefix: '#', title: 'agent-artifacts'),
      SessionMock(id: 'design-notes', prefix: '#', title: 'design-notes'),
    ],
    sessionView: SessionViewMock(
      title: 'ui-foundation',
      rootAgent: 'Manfred',
      entries: <ConversationEntryMock>[
        UserConversationEntryMock(
          author: 'NetHerman2440',
          dateLabel: '15.04.2026',
          timeLabel: '09:22',
          body:
              'Potrzebuję nowych wariantów UI w czacie: link-preview dla toola, ping do agenta i preview wątku dla delegate.',
        ),
        AgentConversationEntryMock(
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:23',
          body:
              'Rozbijam to na trzy widoki w rozmowie. Najpierw zwykły tool call z krótkim preview argumentów, a po rozwinięciu pokażę pełny JSON i output.',
        ),
        ToolCallConversationEntryMock(
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:24',
          toolName: 'search_docs',
          argumentsPreview:
              '{"query":"powodz lubelskie szpitale","limit":3,"include_snippets":true}',
          argumentsJson:
              '{\n  "query": "powodz lubelskie szpitale",\n  "limit": 3,\n  "include_snippets": true\n}',
          outputPreview:
              '{"hits":[{"title":"HydrOS | Powódź"},{"title":"Mapa Zarządzania Kryzysowego"}]}',
          outputJson:
              '{\n  "hits": [\n    {\n      "title": "HydrOS | Powódź",\n      "url": "https://hackaton.mca7d.com/"\n    },\n    {\n      "title": "Mapa Zarządzania Kryzysowego",\n      "url": "https://civil6767.vercel.app/"\n    }\n  ]\n}',
        ),
        AgentConversationEntryMock(
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:25',
          body:
              'Delegate i message potraktuję osobno, żeby nie wyglądały jak zwykły JSON. W linii pokażę ping do agenta z taskiem.',
        ),
        AgentPingConversationEntryMock(
          author: 'Manfred',
          dateLabel: '15.04.2026',
          timeLabel: '09:26',
          agentName: 'research',
          task: 'Znajdź informacje o historii zamku lubelskiego.',
        ),
        AgentThreadConversationEntryMock(
          author: 'research',
          dateLabel: '15.04.2026',
          timeLabel: '09:27',
          threadId: 'thread-research',
          agentName: 'research',
          taskPreview: 'Znajdź informacje o historii zamku lubelskiego.',
          threadTitle: 'Znajdź informacje o historii zamku lubelskim...',
          threadMeta: '92 wiadomości',
          statusLabel: 'W tym wątku nie ma nowych wiadomości.',
        ),
      ],
      threads: <ConversationThreadMock>[
        ConversationThreadMock(
          id: 'thread-research',
          agentName: 'research',
          title: 'Thread research',
          task: 'Znajdź informacje o historii zamku lubelskiego.',
          statusLabel: 'Research czeka na kolejny krok.',
          metaLabel: '92 wiadomości',
          placeholderLabel:
              'Ten widok pokaże pełny transcript delegowanego agenta, gdy backend udostępni precyzyjne grupowanie itemów.',
          entries: <ConversationEntryMock>[
            AgentPingConversationEntryMock(
              author: 'Manfred',
              dateLabel: '15.04.2026',
              timeLabel: '09:26',
              agentName: 'research',
              task: 'Znajdź informacje o historii zamku lubelskiego.',
            ),
            UserPingConversationEntryMock(
              author: 'research',
              dateLabel: '15.04.2026',
              timeLabel: '09:27',
              userName: 'NetHerman2440',
              task:
                  'Doprecyzuj, czy chcesz historię architektury czy wydarzeń.',
            ),
          ],
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
        RailHighlightMock(label: 'Visible items', value: '6'),
      ],
    ),
    currentUser: CurrentUserMock(
      label: 'NH',
      name: 'NetHerman2440',
      status: 'Dostepny',
      color: Color(0xFFF5C271),
    ),
  );
}
