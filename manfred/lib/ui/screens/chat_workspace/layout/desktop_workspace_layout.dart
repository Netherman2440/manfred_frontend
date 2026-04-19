import 'package:flutter/material.dart';

import '../../../core/panel_background.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../columns/additional_column.dart';
import '../columns/agent_column.dart';
import '../columns/conversation_column.dart';
import '../columns/sessions_column.dart';
import 'desktop_workspace_top_bar.dart';
import 'workspace_account_bar.dart';

class DesktopWorkspaceLayout extends StatefulWidget {
  const DesktopWorkspaceLayout({
    super.key,
    required this.workspace,
    required this.showAgentColumn,
    required this.showAdditionalColumn,
    required this.sessionsLoading,
    required this.sessionsErrorMessage,
    required this.conversationLoading,
    required this.conversationErrorMessage,
    required this.onCreateSession,
    required this.onSelectSession,
    required this.onRetrySessions,
    required this.onRetryConversation,
  });

  final WorkspaceMock workspace;
  final bool showAgentColumn;
  final bool showAdditionalColumn;
  final bool sessionsLoading;
  final String? sessionsErrorMessage;
  final bool conversationLoading;
  final String? conversationErrorMessage;
  final VoidCallback onCreateSession;
  final ValueChanged<SessionMock> onSelectSession;
  final VoidCallback onRetrySessions;
  final VoidCallback onRetryConversation;

  @override
  State<DesktopWorkspaceLayout> createState() => _DesktopWorkspaceLayoutState();
}

class _DesktopWorkspaceLayoutState extends State<DesktopWorkspaceLayout> {
  static const double _agentWidth = 92;
  static const double _minSessionsWidth = 200;
  static const double _collapsedSessionsWidth = 176;
  static const double _expandedAdditionalWidth = 308;
  static const double _minConversationWidth = 420;
  static const double _resizeGapWidth = 12;
  static const double _floatingAccountBottom = 20;

  bool _sessionsCollapsed = false;
  bool _additionalVisible = true;
  double _sessionsWidth = _minSessionsWidth;

  @override
  void initState() {
    super.initState();
    _additionalVisible = widget.showAdditionalColumn;
  }

  @override
  void didUpdateWidget(covariant DesktopWorkspaceLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showAdditionalColumn) {
      _additionalVisible = false;
    } else if (!oldWidget.showAdditionalColumn && widget.showAdditionalColumn) {
      _additionalVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showAdditionalPanel =
            widget.showAdditionalColumn && _additionalVisible;
        final maxSessionsWidth = _resolveMaxSessionsWidth(
          totalWidth: constraints.maxWidth,
          showAdditionalPanel: showAdditionalPanel,
        );
        final currentSessionsWidth = _sessionsCollapsed
            ? _collapsedSessionsWidth
            : _sessionsWidth.clamp(_minSessionsWidth, maxSessionsWidth);
        final leftClusterWidth =
            (widget.showAgentColumn ? _agentWidth : 0) + currentSessionsWidth;

        return Column(
          children: <Widget>[
            DesktopWorkspaceTopBar(
              workspace: widget.workspace,
              showAgentColumn: widget.showAgentColumn,
              sessionsWidth: currentSessionsWidth,
              showAdditionalColumn: showAdditionalPanel,
              showResizeGap: !_sessionsCollapsed,
              onToggleAdditionalColumn: widget.showAdditionalColumn
                  ? () {
                      setState(() {
                        _additionalVisible = !_additionalVisible;
                      });
                    }
                  : () {},
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (widget.showAgentColumn)
                        SizedBox(
                          width: _agentWidth,
                          child: _ColumnFrame(
                            child: AgentColumn(agents: widget.workspace.agents),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: currentSessionsWidth,
                        child: _ColumnFrame(
                          background: ManfredColors.sessionsBackground,
                          child: SessionsColumn(
                            sessions: widget.workspace.sessions,
                            rootAgent: widget.workspace.sessionView.rootAgent,
                            isLoading: widget.sessionsLoading,
                            errorMessage: widget.sessionsErrorMessage,
                            onCreateSession: widget.onCreateSession,
                            onSelectSession: widget.onSelectSession,
                            onRetry: widget.onRetrySessions,
                            collapsed: _sessionsCollapsed,
                            onToggleCollapse: () {
                              setState(
                                () => _sessionsCollapsed = !_sessionsCollapsed,
                              );
                            },
                          ),
                        ),
                      ),
                      if (!_sessionsCollapsed)
                        _SessionsResizeHandle(
                          onDragUpdate: (delta) {
                            setState(() {
                              _sessionsWidth = (_sessionsWidth + delta).clamp(
                                _minSessionsWidth,
                                maxSessionsWidth,
                              );
                            });
                          },
                        ),
                      Expanded(
                        child: _ColumnFrame(
                          isMainPanel: true,
                          child: ConversationColumn(
                            sessionView: widget.workspace.sessionView,
                            showCompactHeader: false,
                            isLoading: widget.conversationLoading,
                            errorMessage: widget.conversationErrorMessage,
                            onRetry: widget.onRetryConversation,
                          ),
                        ),
                      ),
                      if (showAdditionalPanel)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: _expandedAdditionalWidth,
                          child: _ColumnFrame(
                            child: AdditionalColumn(
                              data: widget.workspace.rightRail,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: 12,
                    bottom: _floatingAccountBottom,
                    child: WorkspaceAccountBar(
                      user: widget.workspace.currentUser,
                      width: leftClusterWidth,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _resolveMaxSessionsWidth({
    required double totalWidth,
    required bool showAdditionalPanel,
  }) {
    final reservedWidth =
        (widget.showAgentColumn ? _agentWidth : 0) +
        (showAdditionalPanel ? _expandedAdditionalWidth : 0) +
        _minConversationWidth +
        _resizeGapWidth;

    return (totalWidth - reservedWidth)
        .clamp(_minSessionsWidth, 520)
        .toDouble();
  }
}

class _ColumnFrame extends StatelessWidget {
  const _ColumnFrame({
    required this.child,
    this.background = ManfredColors.panelBackground,
    this.isMainPanel = false,
  });

  final Widget child;
  final Color background;
  final bool isMainPanel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isMainPanel ? 10 : 12, 12, 0, 12),
      child: PanelBackground(background: background, child: child),
    );
  }
}

class _SessionsResizeHandle extends StatefulWidget {
  const _SessionsResizeHandle({required this.onDragUpdate});

  final ValueChanged<double> onDragUpdate;

  @override
  State<_SessionsResizeHandle> createState() => _SessionsResizeHandleState();
}

class _SessionsResizeHandleState extends State<_SessionsResizeHandle> {
  static const double _handleWidth = 12;

  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate(details.delta.dx);
        },
        child: SizedBox(
          width: _handleWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: _isHovered ? 3 : 2,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isHovered
                    ? ManfredColors.accentBlue.withValues(alpha: 0.65)
                    : ManfredColors.borderSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
