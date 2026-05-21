import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/chat/application/composer_attachment_picker.dart';
import '../../../../features/chat/application/composer_controller.dart';
import '../../../../features/chat/domain/composer_state.dart';
import '../../../../features/chat/domain/pending_attachment.dart';
import '../../../../features/chat/domain/slash_command.dart';
import '../../../../features/chat/domain/slash_command_matcher.dart';
import '../../../mock/manfred_mock_data.dart';
import '../../../theme/manfred_fonts.dart';
import '../../../theme/manfred_theme.dart';
import 'slash_command_palette.dart';
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
  late final FocusNode _focusNode;
  final GlobalKey<SlashCommandPaletteState> _paletteKey =
      GlobalKey<SlashCommandPaletteState>();
  bool _paletteDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(composerControllerProvider).draft,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _draftStartsWithSlash(String draft) =>
      draft.trimLeft().startsWith('/');

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final composerState = ref.read(composerControllerProvider);
    final draft = composerState.draft;
    final paletteOpen = !_paletteDismissed &&
        _draftStartsWithSlash(draft) &&
        composerState.runningCommand == null;

    if (!paletteOpen) {
      return KeyEventResult.ignored;
    }

    final paletteState = _paletteKey.currentState;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _paletteDismissed = true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      paletteState?.moveSelectionUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      paletteState?.moveSelectionDown();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final resolved = resolveCommand(draft);
      final selected = paletteState?.selectedCommand;
      if (resolved != null &&
          selected != null &&
          resolved.name == selected.name) {
        // Let the composer's send() path run the slash command — keep
        // the controller as the single source of truth for dispatch.
        ref
            .read(composerControllerProvider.notifier)
            .send(
              deliveryAgentId: widget.replyTarget?.deliveryAgentId,
              deliveryCallId: widget.replyTarget?.deliveryCallId,
              rootAgentName: widget.rootAgentName,
            );
        return KeyEventResult.handled;
      }
      // No exact match → fall through to TextField's onSubmitted (normal send).
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ComposerState>(composerControllerProvider, (previous, next) {
      // Re-open the palette whenever the draft changes and starts with `/`
      // again — esc-dismissal should only last until the user keeps typing.
      if (previous?.draft != next.draft && _draftStartsWithSlash(next.draft)) {
        if (_paletteDismissed) {
          _paletteDismissed = false;
        }
      }
      if (_controller.text == next.draft) {
        return;
      }

      _controller.value = TextEditingValue(
        text: next.draft,
        selection: TextSelection.collapsed(offset: next.draft.length),
      );
    });

    final state = ref.watch(composerControllerProvider);
    final isRunningCommand = state.runningCommand != null;
    final canSend =
        !state.isSending &&
        !state.isEditing &&
        !isRunningCommand &&
        state.draft.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;
    final replyTarget = widget.replyTarget;
    final showStop = state.canStop;
    final hintText = state.isEditing
        ? 'Zakończ edycję wiadomości w historii, aby wrócić do composera...'
        : replyTarget == null
        ? 'Napisz wiadomość do sesji...'
        : 'Napisz odpowiedź do ${replyTarget.agentLabel}';

    // Slash-command palette gating.
    final paletteVisible = !_paletteDismissed &&
        !isRunningCommand &&
        !state.isEditing &&
        _draftStartsWithSlash(state.draft);
    final paletteQuery = paletteVisible ? (parseSlashQuery(state.draft) ?? '') : '';
    final filteredCommands =
        paletteVisible ? filterCommands(paletteQuery) : const <SlashCommand>[];

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
          if (state.attachments.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.attachments
                    .map(
                      (attachment) => _ComposerAttachmentChip(
                        attachment: attachment,
                        onRemove: () {
                          ref
                              .read(composerControllerProvider.notifier)
                              .removeAttachment(attachment.localId);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (paletteVisible)
            SlashCommandPalette(
              key: _paletteKey,
              commands: filteredCommands,
              query: paletteQuery,
              onCommandSelected: (cmd) {
                ref
                    .read(composerControllerProvider.notifier)
                    .updateDraft('/${cmd.name}');
                ref
                    .read(composerControllerProvider.notifier)
                    .send(
                      deliveryAgentId: replyTarget?.deliveryAgentId,
                      deliveryCallId: replyTarget?.deliveryCallId,
                      rootAgentName: widget.rootAgentName,
                    );
              },
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              IgnorePointer(
                ignoring: state.isEditing || isRunningCommand,
                child: Opacity(
                  opacity: (state.isEditing || isRunningCommand) ? 0.4 : 1,
                  child: WorkspaceIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Attach',
                    onTap: () async {
                      final attachments = await ref
                          .read(composerAttachmentPickerProvider)
                          .pickAttachments();
                      if (!mounted || attachments.isEmpty) {
                        return;
                      }
                      ref
                          .read(composerControllerProvider.notifier)
                          .addAttachments(attachments);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComposerInputContainer(
                  isLoading: isRunningCommand,
                  child: Focus(
                    focusNode: _focusNode,
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _controller,
                      enabled: !state.isEditing && !isRunningCommand,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.send,
                      onChanged: (value) {
                        if (_paletteDismissed && _draftStartsWithSlash(value)) {
                          setState(() => _paletteDismissed = false);
                        }
                        ref
                            .read(composerControllerProvider.notifier)
                            .updateDraft(value);
                      },
                      onSubmitted: (_) {
                        if (canSend) {
                          ref
                              .read(composerControllerProvider.notifier)
                              .send(
                                deliveryAgentId:
                                    replyTarget?.deliveryAgentId,
                                deliveryCallId: replyTarget?.deliveryCallId,
                                rootAgentName: widget.rootAgentName,
                              );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: hintText,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showStop) ...<Widget>[
                    IgnorePointer(
                      ignoring: state.isStopping,
                      child: Opacity(
                        opacity: state.isStopping ? 0.55 : 1,
                        child: WorkspaceIconButton(
                          icon: state.isStopping
                              ? Icons.hourglass_top_rounded
                              : Icons.stop_rounded,
                          tooltip: 'Stop',
                          onTap: () {
                            ref
                                .read(composerControllerProvider.notifier)
                                .stop();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _SendOrSpinner(
                    isRunningCommand: isRunningCommand,
                    canSend: canSend,
                    isSending: state.isSending,
                    onSend: () {
                      ref
                          .read(composerControllerProvider.notifier)
                          .send(
                            deliveryAgentId: replyTarget?.deliveryAgentId,
                            deliveryCallId: replyTarget?.deliveryCallId,
                            rootAgentName: widget.rootAgentName,
                          );
                    },
                  ),
                ],
              ),
            ],
          ),
          if (isRunningCommand) ...<Widget>[
            const SizedBox(height: 4),
            const _RecollectingStatusRow(),
          ],
        ],
      ),
    );
  }
}

/// Container for the TextField — owns the (optionally pulsing) border.
class _ComposerInputContainer extends StatefulWidget {
  const _ComposerInputContainer({required this.isLoading, required this.child});

  final bool isLoading;
  final Widget child;

  @override
  State<_ComposerInputContainer> createState() =>
      _ComposerInputContainerState();
}

class _ComposerInputContainerState extends State<_ComposerInputContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_ComposerInputContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.isLoading ? _controller.value : 0.0;
        final borderColor = widget.isLoading
            ? Color.lerp(
                ManfredColors.accentBlue.withValues(alpha: 0.55),
                ManfredColors.accentBlue.withValues(alpha: 0.9),
                t,
              )!
            : ManfredColors.borderSubtle;
        return Container(
          decoration: BoxDecoration(
            color: ManfredColors.panelAltBackground,
            borderRadius: BorderRadius.circular(ManfredShapes.inputRadius),
            border: Border.all(color: borderColor),
            boxShadow: widget.isLoading
                ? <BoxShadow>[
                    BoxShadow(
                      color: ManfredColors.accentBlue.withValues(
                        alpha: 0.15 + 0.15 * t,
                      ),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SendOrSpinner extends StatelessWidget {
  const _SendOrSpinner({
    required this.isRunningCommand,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  final bool isRunningCommand;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (isRunningCommand) {
      // Same geometry as WorkspaceIconButton primary action — no layout jump.
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ManfredColors.panelOverlay,
          border: Border.all(color: ManfredColors.accentBlue),
          borderRadius: BorderRadius.circular(ManfredShapes.buttonRadius),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              ManfredColors.accentBlue,
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: !canSend,
      child: Opacity(
        opacity: canSend ? 1 : 0.45,
        child: WorkspaceIconButton(
          icon: isSending
              ? Icons.hourglass_top_rounded
              : Icons.send_rounded,
          tooltip: 'Send',
          isPrimary: true,
          onTap: onSend,
        ),
      ),
    );
  }
}

class _RecollectingStatusRow extends StatefulWidget {
  const _RecollectingStatusRow();

  @override
  State<_RecollectingStatusRow> createState() => _RecollectingStatusRowState();
}

class _RecollectingStatusRowState extends State<_RecollectingStatusRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyphStyle = ManfredFonts.serif(
      const TextStyle(
        fontStyle: FontStyle.italic,
        fontSize: 17,
        height: 1,
        color: ManfredColors.accentBlue,
        fontWeight: FontWeight.w400,
      ),
    );
    final labelStyle = ManfredFonts.sans(
      const TextStyle(
        fontSize: 13,
        height: 1.4,
        color: ManfredColors.textSecondary,
        letterSpacing: 0.1,
      ),
    );
    final metaStyle = ManfredFonts.mono(
      const TextStyle(
        fontSize: 11,
        height: 1.4,
        color: ManfredColors.textMuted,
        letterSpacing: 0.4,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        // Note: Flutter has no first-class dashed border in BoxDecoration —
        // we use a solid 1px borderSubtle as an acceptable substitute per the
        // T4 spec.
        border: Border(top: BorderSide(color: ManfredColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text('~', style: glyphStyle),
          const SizedBox(width: 12),
          Text('Recollecting', style: labelStyle),
          const SizedBox(width: 6),
          _AnimatedDots(controller: _dotsController),
          const Spacer(),
          Flexible(
            child: Text(
              'may take ~20s · do not refresh',
              style: metaStyle,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  const _AnimatedDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 6,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          double dotOpacity(double phase) {
            // Staggered triangular fade — peaks at 40% of the cycle.
            final v = (controller.value - phase) % 1.0;
            if (v < 0) return 0.25;
            final eased = v < 0.4 ? v / 0.4 : (1.0 - v) / 0.6;
            return 0.25 + (eased.clamp(0.0, 1.0)) * 0.75;
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _Dot(opacity: dotOpacity(0.0)),
              const SizedBox(width: 3),
              _Dot(opacity: dotOpacity(0.15)),
              const SizedBox(width: 3),
              _Dot(opacity: dotOpacity(0.30)),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: ManfredColors.accentBlue.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ComposerAttachmentChip extends StatelessWidget {
  const _ComposerAttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  final PendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.attach_file_rounded, size: 16),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              '${attachment.fileName} · ${_formatSize(attachment.sizeBytes)}',
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: ManfredColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int sizeBytes) {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
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
