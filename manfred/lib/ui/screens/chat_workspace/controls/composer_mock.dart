import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/chat/application/composer_controller.dart';
import '../../../../features/chat/domain/composer_state.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_theme.dart';
import 'workspace_icon_button.dart';

class ComposerMock extends ConsumerStatefulWidget {
  const ComposerMock({
    super.key,
    required this.showCompactLayout,
    this.replyTarget,
    this.rootAgentName,
  });

  final bool showCompactLayout;
  final ComposerReplyTargetMock? replyTarget;
  final String? rootAgentName;

  @override
  ConsumerState<ComposerMock> createState() => _ComposerMockState();
}

class _ComposerMockState extends ConsumerState<ComposerMock> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(composerControllerProvider).draft,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ComposerState>(composerControllerProvider, (previous, next) {
      if (_controller.text == next.draft) {
        return;
      }

      _controller.value = TextEditingValue(
        text: next.draft,
        selection: TextSelection.collapsed(offset: next.draft.length),
      );
    });

    final state = ref.watch(composerControllerProvider);
    final canSend = !state.isBusy && state.draft.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;
    final replyTarget = widget.replyTarget;
    final showStop = state.canStop;
    final hintText = replyTarget == null
        ? 'Napisz wiadomość do sesji...'
        : 'Napisz odpowiedź do ${replyTarget.agentLabel}';

    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.showCompactLayout ? 14 : 22,
        14,
        widget.showCompactLayout ? 14 : 22,
        18,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ManfredColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (replyTarget != null) ...<Widget>[
            _ReplyTargetBanner(
              replyTarget: replyTarget,
              showCompactLayout: widget.showCompactLayout,
            ),
            const SizedBox(height: 10),
          ],
          if (state.errorMessage != null) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  state.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: ManfredColors.accentRed,
                  ),
                ),
              ),
            ),
          ],
          Row(
            children: <Widget>[
              WorkspaceIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Attach',
                onTap: () {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ManfredColors.panelAltBackground,
                    borderRadius: BorderRadius.circular(
                      ManfredShapes.inputRadius,
                    ),
                    border: Border.all(color: ManfredColors.borderSubtle),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !state.isBusy,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onChanged: ref
                        .read(composerControllerProvider.notifier)
                        .updateDraft,
                    onSubmitted: (_) {
                      if (canSend) {
                        ref
                            .read(composerControllerProvider.notifier)
                            .send(
                              deliveryAgentId: replyTarget?.deliveryAgentId,
                              deliveryCallId: replyTarget?.deliveryCallId,
                              rootAgentName: widget.rootAgentName,
                            );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (showStop)
                IgnorePointer(
                  ignoring: state.isStopping,
                  child: Opacity(
                    opacity: state.isStopping ? 0.55 : 1,
                    child: WorkspaceIconButton(
                      icon: state.isStopping
                          ? Icons.hourglass_top_rounded
                          : Icons.stop_rounded,
                      tooltip: 'Stop',
                      isPrimary: true,
                      onTap: () {
                        ref.read(composerControllerProvider.notifier).stop();
                      },
                    ),
                  ),
                )
              else
                IgnorePointer(
                  ignoring: !canSend,
                  child: Opacity(
                    opacity: canSend ? 1 : 0.45,
                    child: WorkspaceIconButton(
                      icon: state.isSending
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      tooltip: 'Send',
                      isPrimary: true,
                      onTap: () {
                        ref
                            .read(composerControllerProvider.notifier)
                            .send(
                              deliveryAgentId: replyTarget?.deliveryAgentId,
                              deliveryCallId: replyTarget?.deliveryCallId,
                              rootAgentName: widget.rootAgentName,
                            );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyTargetBanner extends StatelessWidget {
  const _ReplyTargetBanner({
    required this.replyTarget,
    required this.showCompactLayout,
  });

  final ComposerReplyTargetMock replyTarget;
  final bool showCompactLayout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: showCompactLayout ? 12 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Odpowiadasz do ${replyTarget.agentLabel}',
            style: textTheme.labelLarge?.copyWith(
              color: ManfredColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyTarget.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: ManfredColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
