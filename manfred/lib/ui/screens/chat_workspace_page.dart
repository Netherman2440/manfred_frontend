import 'package:flutter/material.dart';

import '../mock/manfred_mock_data.dart';
import '../theme/manfred_theme.dart';

class ChatWorkspacePage extends StatelessWidget {
  const ChatWorkspacePage({super.key, required this.workspace});

  final WorkspaceMock workspace;

  @override
  Widget build(BuildContext context) {
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
                return _MobileWorkspace(workspace: workspace);
              }

              final showAgentRail = constraints.maxWidth >= 960;
              final showRightRail = constraints.maxWidth >= 1280;

              return Row(
                children: <Widget>[
                  if (showAgentRail)
                    SizedBox(
                      width: 92,
                      child: _PanelShell(
                        child: _AgentRail(agents: workspace.agents),
                      ),
                    ),
                  SizedBox(
                    width: showAgentRail ? 280 : 256,
                    child: _PanelShell(
                      background: ManfredColors.sessionsBackground,
                      child: _SessionRail(
                        sessions: workspace.sessions,
                        rootAgent: workspace.sessionView.rootAgent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _PanelShell(
                      isMainPanel: true,
                      child: _ConversationPanel(
                        sessionView: workspace.sessionView,
                        showCompactHeader: false,
                      ),
                    ),
                  ),
                  if (showRightRail)
                    SizedBox(
                      width: 308,
                      child: _PanelShell(
                        child: _RightRail(data: workspace.rightRail),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobileWorkspace extends StatelessWidget {
  const _MobileWorkspace({required this.workspace});

  final WorkspaceMock workspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CompactTopBar(agents: workspace.agents),
        _CompactSessionStrip(
          sessions: workspace.sessions,
          rootAgent: workspace.sessionView.rootAgent,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: _panelDecoration(),
              child: _ConversationPanel(
                sessionView: workspace.sessionView,
                showCompactHeader: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
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
      child: DecoratedBox(
        decoration: _panelDecoration(background: background),
        child: child,
      ),
    );
  }
}

class _AgentRail extends StatelessWidget {
  const _AgentRail({required this.agents});

  final List<AgentMock> agents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.topCenter,
              child: _RailUtilityButton(
                icon: Icons.home_rounded,
                tooltip: 'Home',
                onTap: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: agents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agent = agents[index];
                return Tooltip(
                  message: agent.name,
                  child: _AgentRailItem(agent: agent),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.topCenter,
              child: _RailUtilityButton(
                icon: Icons.add_rounded,
                tooltip: 'New root agent',
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentRailItem extends StatefulWidget {
  const _AgentRailItem({required this.agent});

  final AgentMock agent;

  @override
  State<_AgentRailItem> createState() => _AgentRailItemState();
}

class _AgentRailItemState extends State<_AgentRailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final markerColor = widget.agent.isActive
        ? widget.agent.color
        : (_isHovered ? ManfredColors.borderStrong : Colors.transparent);
    final markerHeight = widget.agent.isActive
        ? 44.0
        : (_isHovered ? 18.0 : 0.0);
    final markerTop = widget.agent.isActive ? 5.0 : 18.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              left: 0,
              top: markerTop,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: 4,
                height: markerHeight,
                decoration: BoxDecoration(
                  color: markerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: ManfredColors.panelOverlay,
                        shape: BoxShape.circle,
                        border: Border.all(color: ManfredColors.borderSubtle),
                      ),
                      child: Center(
                        child: Text(
                          widget.agent.label,
                          style: textTheme.labelLarge?.copyWith(
                            color: widget.agent.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.agent.name,
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: widget.agent.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRail extends StatelessWidget {
  const _SessionRail({required this.sessions, required this.rootAgent});

  final List<SessionMock> sessions;
  final String rootAgent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Sessions', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Root agent: $rootAgent', style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 18),
          _OutlineActionButton(
            icon: Icons.add_rounded,
            label: 'New Session',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                return _SessionRailTile(session: sessions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRailTile extends StatefulWidget {
  const _SessionRailTile({required this.session});

  final SessionMock session;

  @override
  State<_SessionRailTile> createState() => _SessionRailTileState();
}

class _SessionRailTileState extends State<_SessionRailTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isHighlighted = _isHovered || widget.session.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isHighlighted
              ? ManfredColors.messageHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ManfredShapes.tileRadius),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          minLeadingWidth: 18,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ManfredShapes.tileRadius),
          ),
          leading: Text(
            widget.session.prefix,
            style: textTheme.titleMedium?.copyWith(
              color: widget.session.isActive
                  ? ManfredColors.textPrimary
                  : ManfredColors.textMuted,
            ),
          ),
          title: Text(
            widget.session.title,
            style: textTheme.bodyMedium?.copyWith(
              color: widget.session.isActive
                  ? ManfredColors.textPrimary
                  : ManfredColors.textSecondary,
              fontWeight: widget.session.isActive
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
          onTap: () {},
        ),
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
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
              _IconButtonCard(
                icon: Icons.tune_rounded,
                tooltip: 'Session options',
                onTap: () {},
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            itemCount: sessionView.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              final entry = sessionView.entries[index];
              return switch (entry.type) {
                ConversationEntryType.userMessage => _MessageEntry(
                  entry: entry,
                  accent: ManfredColors.accentBlue,
                ),
                ConversationEntryType.assistantMessage => _MessageEntry(
                  entry: entry,
                  accent: ManfredColors.accentGreen,
                ),
                ConversationEntryType.toolCard => _ToolCardEntry(entry: entry),
                ConversationEntryType.delegateThread => _DelegateThreadEntry(
                  entry: entry,
                ),
              };
            },
          ),
        ),
        _ComposerMock(showCompactLayout: showCompactHeader),
      ],
    );
  }
}

class _HoverSurface extends StatefulWidget {
  const _HoverSurface({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isHovered ? ManfredColors.messageHover : Colors.transparent,
          borderRadius: BorderRadius.circular(ManfredShapes.tileRadius),
        ),
        child: widget.child,
      ),
    );
  }
}

class _MessageEntry extends StatelessWidget {
  const _MessageEntry({required this.entry, required this.accent});

  final ConversationEntryMock entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _HoverSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ManfredColors.panelOverlay,
              shape: BoxShape.circle,
              border: Border.all(color: ManfredColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                entry.author.characters.first.toUpperCase(),
                style: textTheme.labelLarge?.copyWith(color: accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      entry.author,
                      style: textTheme.labelLarge?.copyWith(color: accent),
                    ),
                    Text(
                      '${entry.dateLabel} ${entry.timeLabel}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(entry.body ?? '', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCardEntry extends StatelessWidget {
  const _ToolCardEntry({required this.entry});

  final ConversationEntryMock entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        border: Border.all(color: ManfredColors.borderStrong),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.extension_rounded,
                color: ManfredColors.accentAmber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.title ?? '', style: textTheme.titleSmall),
              ),
              _RoleBadge(
                label: (entry.status ?? '').toUpperCase(),
                color: ManfredColors.accentAmber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(entry.body ?? '', style: textTheme.bodyMedium),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ManfredColors.panelBackground,
              borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
              border: Border.all(color: ManfredColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.previewTitle ?? '', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(entry.previewBody ?? '', style: textTheme.bodySmall),
              ],
            ),
          ),
          if (entry.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.tags
                  .map(
                    (tag) =>
                        _TagPill(label: tag, color: ManfredColors.accentAmber),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${entry.dateLabel} ${entry.timeLabel}',
              style: textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DelegateThreadEntry extends StatelessWidget {
  const _DelegateThreadEntry({required this.entry});

  final ConversationEntryMock entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ManfredColors.panelRaised,
        borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 2,
            height: 112,
            margin: const EdgeInsets.only(right: 14, top: 2),
            decoration: BoxDecoration(
              color: ManfredColors.accentBlue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    Text(entry.author, style: textTheme.labelLarge),
                    _RoleBadge(
                      label: 'DELEGATE',
                      color: ManfredColors.accentBlue,
                    ),
                    Text(
                      '${entry.dateLabel} ${entry.timeLabel}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(entry.title ?? '', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                Text(entry.body ?? '', style: textTheme.bodyMedium),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    _TagPill(
                      label: '${entry.threadCount ?? 0} wiadomości',
                      color: ManfredColors.accentBlue,
                    ),
                    const SizedBox(width: 8),
                    ...entry.tags.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TagPill(
                          label: tag,
                          color: ManfredColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerMock extends StatelessWidget {
  const _ComposerMock({required this.showCompactLayout});

  final bool showCompactLayout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        showCompactLayout ? 14 : 22,
        14,
        showCompactLayout ? 14 : 22,
        18,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ManfredColors.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          _IconButtonCard(
            icon: Icons.add_rounded,
            tooltip: 'Attach',
            onTap: () {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ManfredColors.panelAltBackground,
                borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
                border: Border.all(color: ManfredColors.borderSubtle),
              ),
              child: Text(
                'Napisz wiadomość do sesji...',
                style: textTheme.bodyMedium?.copyWith(
                  color: ManfredColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconButtonCard(
            icon: Icons.send_rounded,
            tooltip: 'Send',
            isPrimary: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({required this.data});

  final RightRailMock data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Artifacts', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Pliki, wątki i stan sesji', style: textTheme.bodySmall),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: <Widget>[
                ...data.highlights.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ManfredColors.panelAltBackground,
                        borderRadius: BorderRadius.circular(
                          ManfredShapes.inputRadius,
                        ),
                        border: Border.all(color: ManfredColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.label, style: textTheme.labelSmall),
                          const SizedBox(height: 6),
                          Text(item.value, style: textTheme.labelLarge),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Resources', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                ...data.resources.map(
                  (resource) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ManfredColors.panelBackground,
                        borderRadius: BorderRadius.circular(
                          ManfredShapes.inputRadius,
                        ),
                        border: Border.all(color: ManfredColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _TagPill(
                                label: resource.kind,
                                color: ManfredColors.accentBlue,
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(resource.title, style: textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Text(resource.meta, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({required this.agents});

  final List<AgentMock> agents;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Agents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: agents
                  .map(
                    (agent) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ManfredColors.panelAltBackground,
                          borderRadius: BorderRadius.circular(
                            ManfredShapes.inputRadius,
                          ),
                          border: Border.all(
                            color: agent.isActive
                                ? agent.color.withValues(alpha: 0.45)
                                : ManfredColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          '${agent.label} ${agent.name}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: agent.color),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSessionStrip extends StatelessWidget {
  const _CompactSessionStrip({required this.sessions, required this.rootAgent});

  final List<SessionMock> sessions;
  final String rootAgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 198,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(
        background: ManfredColors.sessionsBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Root agent: $rootAgent',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _OutlineActionButton(
            icon: Icons.add_rounded,
            label: 'New Session',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final session = sessions[index];

                return Container(
                  width: 190,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: session.isActive
                        ? ManfredColors.messageHover
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      ManfredShapes.tileRadius,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        session.prefix,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: ManfredColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RailUtilityButton extends StatelessWidget {
  const _RailUtilityButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: ManfredColors.panelOverlay,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: ManfredColors.borderSubtle),
            ),
          ),
          child: Icon(icon, color: ManfredColors.textPrimary),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _IconButtonCard extends StatelessWidget {
  const _IconButtonCard({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isPrimary
                ? ManfredColors.accentBlue
                : ManfredColors.panelAltBackground,
            borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
            border: Border.all(
              color: isPrimary
                  ? ManfredColors.accentBlue.withValues(alpha: 0.75)
                  : ManfredColors.borderSubtle,
            ),
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? ManfredColors.appBackground
                : ManfredColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatefulWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlineActionButton> createState() => _OutlineActionButtonState();
}

class _OutlineActionButtonState extends State<_OutlineActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
        onTap: widget.onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? ManfredColors.messageHover : Colors.transparent,
            borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
            border: Border.all(color: ManfredColors.borderStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(widget.icon, size: 18, color: ManfredColors.textPrimary),
              const SizedBox(width: 8),
              Text(widget.label, style: textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({
  Color background = ManfredColors.panelBackground,
}) {
  return BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(ManfredShapes.panelRadius),
    border: Border.all(color: ManfredColors.borderSubtle),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 22,
        offset: Offset(0, 12),
      ),
    ],
  );
}
