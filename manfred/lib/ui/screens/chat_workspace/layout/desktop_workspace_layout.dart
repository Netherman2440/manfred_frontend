import 'package:flutter/material.dart';

import '../../../core/panel_background.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import '../columns/additional_column.dart';
import '../columns/agent_column.dart';
import '../columns/conversation_column.dart';
import '../columns/sessions_column.dart';

class DesktopWorkspaceLayout extends StatefulWidget {
  const DesktopWorkspaceLayout({
    super.key,
    required this.workspace,
    required this.showAgentColumn,
    required this.showAdditionalColumn,
  });

  final WorkspaceMock workspace;
  final bool showAgentColumn;
  final bool showAdditionalColumn;

  @override
  State<DesktopWorkspaceLayout> createState() => _DesktopWorkspaceLayoutState();
}

class _DesktopWorkspaceLayoutState extends State<DesktopWorkspaceLayout> {
  static const double _minSessionsWidth = 280;
  static const double _collapsedSessionsWidth = 176;
  static const double _collapsedAdditionalWidth = 84;
  static const double _expandedAdditionalWidth = 308;
  static const double _minConversationWidth = 420;

  bool _sessionsCollapsed = false;
  bool _additionalCollapsed = false;
  double _sessionsWidth = _minSessionsWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSessionsWidth = _resolveMaxSessionsWidth(constraints.maxWidth);
        final currentSessionsWidth = _sessionsCollapsed
            ? _collapsedSessionsWidth
            : _sessionsWidth.clamp(_minSessionsWidth, maxSessionsWidth);

        return Row(
          children: <Widget>[
            if (widget.showAgentColumn)
              SizedBox(
                width: 92,
                child: _ColumnFrame(
                  child: AgentColumn(agents: widget.workspace.agents),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: currentSessionsWidth,
              child: Stack(
                children: <Widget>[
                  _ColumnFrame(
                    background: ManfredColors.sessionsBackground,
                    child: SessionsColumn(
                      sessions: widget.workspace.sessions,
                      rootAgent: widget.workspace.sessionView.rootAgent,
                      collapsed: _sessionsCollapsed,
                      onToggleCollapse: () {
                        setState(
                          () => _sessionsCollapsed = !_sessionsCollapsed,
                        );
                      },
                    ),
                  ),
                  if (!_sessionsCollapsed)
                    Positioned(
                      top: 12,
                      bottom: 12,
                      right: 0,
                      child: _SessionsResizeHandle(
                        onDragUpdate: (delta) {
                          setState(() {
                            _sessionsWidth = (_sessionsWidth + delta).clamp(
                              _minSessionsWidth,
                              maxSessionsWidth,
                            );
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _ColumnFrame(
                isMainPanel: true,
                child: ConversationColumn(
                  sessionView: widget.workspace.sessionView,
                  showCompactHeader: false,
                ),
              ),
            ),
            if (widget.showAdditionalColumn)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: _additionalCollapsed
                    ? _collapsedAdditionalWidth
                    : _expandedAdditionalWidth,
                child: _ColumnFrame(
                  child: AdditionalColumn(
                    data: widget.workspace.rightRail,
                    collapsed: _additionalCollapsed,
                    onToggleCollapse: () {
                      setState(
                        () => _additionalCollapsed = !_additionalCollapsed,
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _resolveMaxSessionsWidth(double totalWidth) {
    final reservedWidth =
        (widget.showAgentColumn ? 92 : 0) +
        (widget.showAdditionalColumn
            ? (_additionalCollapsed
                  ? _collapsedAdditionalWidth
                  : _expandedAdditionalWidth)
            : 0) +
        _minConversationWidth;

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
        child: Container(
          width: 14,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: _isHovered ? 3 : 2,
            decoration: BoxDecoration(
              color: _isHovered
                  ? ManfredColors.accentBlue.withValues(alpha: 0.65)
                  : ManfredColors.borderSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
