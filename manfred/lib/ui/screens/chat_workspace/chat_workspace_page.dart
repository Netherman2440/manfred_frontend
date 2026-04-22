import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/chat/application/composer_controller.dart';
import '../../../features/sessions/application/session_details_provider.dart';
import '../../../features/sessions/application/sessions_list_provider.dart';
import '../../../features/sessions/application/selected_session_provider.dart';
import '../../../features/sessions/domain/session_details.dart';
import '../../../features/sessions/domain/session_list_entry.dart';
import '../../../features/sessions/presentation/workspace_view_mapper.dart';
import '../../mock/manfred_mock_data.dart';
import '../../theme/manfred_theme.dart';
import 'layout/desktop_workspace_layout.dart';
import 'layout/mobile_workspace_layout.dart';

class ChatWorkspacePage extends ConsumerWidget {
  const ChatWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseWorkspace = ManfredMockData.workspace;
    final selection = ref.watch(selectedSessionProvider);
    final sessionsAsync = ref.watch(sessionsListProvider);
    final detailsAsync = ref.watch(sessionDetailsProvider);
    final sessions = sessionsAsync.valueOrNull ?? const <SessionListEntry>[];

    _maybeSelectFirstSession(ref, selection, sessions);

    final selectedSession = selection.sessionId == null
        ? null
        : _findSelectedSession(sessions, selection.sessionId);
    final rootAgentName =
        detailsAsync.valueOrNull?.rootAgent.name ??
        selectedSession?.rootAgentName ??
        baseWorkspace.sessionView.rootAgent;
    final sessionView = _buildCurrentSessionView(
      baseWorkspace: baseWorkspace,
      selection: selection,
      sessions: sessions,
      selectedSession: selectedSession,
      detailsAsync: detailsAsync,
    );
    final workspace = baseWorkspace.copyWith(
      sessions: buildSessionMocks(
        sessions,
        activeSessionId: selection.sessionId,
        isDraft: selection.isDraft,
      ),
      sessionView: sessionView.copyWith(rootAgent: rootAgentName),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ManfredColors.appBackground,
              Color(0xFF14100D),
              ManfredColors.appBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return MobileWorkspaceLayout(
                  workspace: workspace,
                  sessionsLoading: sessionsAsync.isLoading,
                  sessionsErrorMessage: _asyncErrorMessage(sessionsAsync),
                  conversationLoading:
                      selection.sessionId != null && detailsAsync.isLoading,
                  conversationErrorMessage: _asyncErrorMessage(detailsAsync),
                  onCreateSession: () => _startDraft(ref),
                  onSelectSession: (session) => _selectSession(ref, session),
                  onRetrySessions: () => ref.invalidate(sessionsListProvider),
                  onRetryConversation: () =>
                      ref.invalidate(sessionDetailsProvider),
                );
              }

              return DesktopWorkspaceLayout(
                workspace: workspace,
                showAgentColumn: constraints.maxWidth >= 960,
                showAdditionalColumn: constraints.maxWidth >= 1280,
                sessionsLoading: sessionsAsync.isLoading,
                sessionsErrorMessage: _asyncErrorMessage(sessionsAsync),
                conversationLoading:
                    selection.sessionId != null && detailsAsync.isLoading,
                conversationErrorMessage: _asyncErrorMessage(detailsAsync),
                onCreateSession: () => _startDraft(ref),
                onSelectSession: (session) => _selectSession(ref, session),
                onRetrySessions: () => ref.invalidate(sessionsListProvider),
                onRetryConversation: () =>
                    ref.invalidate(sessionDetailsProvider),
              );
            },
          ),
        ),
      ),
    );
  }

  void _maybeSelectFirstSession(
    WidgetRef ref,
    SelectedSessionState selection,
    List<SessionListEntry> sessions,
  ) {
    if (selection.sessionId != null || selection.isDraft || sessions.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latestSelection = ref.read(selectedSessionProvider);
      if (latestSelection.sessionId == null && !latestSelection.isDraft) {
        ref.read(selectedSessionProvider.notifier).select(sessions.first.id);
      }
    });
  }

  SessionListEntry? _findSelectedSession(
    List<SessionListEntry> sessions,
    String? selectedSessionId,
  ) {
    if (selectedSessionId == null) {
      return null;
    }

    for (final session in sessions) {
      if (session.id == selectedSessionId) {
        return session;
      }
    }

    return null;
  }

  SessionViewMock _buildCurrentSessionView({
    required WorkspaceMock baseWorkspace,
    required SelectedSessionState selection,
    required List<SessionListEntry> sessions,
    required SessionListEntry? selectedSession,
    required AsyncValue<SessionDetails?> detailsAsync,
  }) {
    if (selection.isDraft) {
      return const SessionViewMock(
        title: 'New session',
        rootAgent: 'Manfred',
        entries: <ConversationEntryMock>[],
        threads: <ConversationThreadMock>[],
      );
    }

    final details = detailsAsync.valueOrNull;
    if (details != null) {
      return buildSessionViewMock(
        details,
        currentUserName: baseWorkspace.currentUser.name,
      );
    }

    if (detailsAsync.hasError) {
      return SessionViewMock(
        title: selectedSession?.displayTitle ?? 'Session',
        rootAgent: selectedSession?.rootAgentName ?? 'Manfred',
        entries: <ConversationEntryMock>[
          AgentConversationEntryMock(
            author: selectedSession?.rootAgentName ?? 'Manfred',
            dateLabel: '',
            timeLabel: '',
            body: 'Nie udało się załadować historii sesji.',
          ),
        ],
        threads: const <ConversationThreadMock>[],
      );
    }

    if (selection.sessionId != null) {
      return SessionViewMock(
        title: selectedSession?.displayTitle ?? 'Session',
        rootAgent: selectedSession?.rootAgentName ?? 'Manfred',
        entries: <ConversationEntryMock>[
          AgentConversationEntryMock(
            author: selectedSession?.rootAgentName ?? 'Manfred',
            dateLabel: '',
            timeLabel: '',
            body: 'Ładowanie historii sesji...',
          ),
        ],
        threads: const <ConversationThreadMock>[],
      );
    }

    if (sessions.isEmpty) {
      return const SessionViewMock(
        title: 'New session',
        rootAgent: 'Manfred',
        entries: <ConversationEntryMock>[
          AgentConversationEntryMock(
            author: 'Manfred',
            dateLabel: '',
            timeLabel: '',
            body: 'Brak sesji. Zacznij od nowej wiadomości.',
          ),
        ],
        threads: <ConversationThreadMock>[],
      );
    }

    return baseWorkspace.sessionView;
  }

  void _startDraft(WidgetRef ref) {
    ref.read(selectedSessionProvider.notifier).startDraft();
    ref.read(composerControllerProvider.notifier).resetDraft();
  }

  void _selectSession(WidgetRef ref, SessionMock session) {
    ref.read(selectedSessionProvider.notifier).select(session.id);
    ref.read(composerControllerProvider.notifier).resetDraft();
  }

  String? _asyncErrorMessage(AsyncValue<dynamic> value) {
    return value.whenOrNull(error: (error, _) => error.toString());
  }
}
