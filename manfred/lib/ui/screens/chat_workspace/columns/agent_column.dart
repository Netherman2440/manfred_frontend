import 'package:flutter/material.dart';

import '../../../core/agent_avatar.dart';
import '../../../core/hover_tile_container.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';

class AgentColumn extends StatelessWidget {
  const AgentColumn({super.key, required this.agents, this.compact = false});

  final List<AgentMock> agents;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact
        ? _CompactAgentColumn(agents: agents)
        : _DesktopAgentColumn(agents: agents);
  }
}

class _DesktopAgentColumn extends StatelessWidget {
  const _DesktopAgentColumn({required this.agents});

  final List<AgentMock> agents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: <Widget>[
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
        ],
      ),
    );
  }
}

class _CompactAgentColumn extends StatelessWidget {
  const _CompactAgentColumn({required this.agents});

  final List<AgentMock> agents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
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
                      child: HoverTileContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isActive: agent.isActive,
                        baseColor: ManfredColors.panelAltBackground,
                        child: Row(
                          children: <Widget>[
                            AgentAvatar(
                              label: agent.label,
                              accentColor: agent.color,
                              size: 34,
                              isActive: agent.isActive,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              agent.name,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: agent.color),
                            ),
                          ],
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
                    AgentAvatar(
                      label: widget.agent.label,
                      accentColor: widget.agent.color,
                      size: 54,
                      isActive: widget.agent.isActive,
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
