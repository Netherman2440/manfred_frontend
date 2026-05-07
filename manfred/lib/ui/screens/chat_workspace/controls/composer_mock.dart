import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/chat/application/composer_attachment_picker.dart';
import '../../../../features/chat/application/composer_controller.dart';
import '../../../../features/chat/domain/composer_state.dart';
import '../../../../features/chat/domain/pending_attachment.dart';
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
    final canSend =
        !state.isSending &&
        !state.isEditing &&
        state.draft.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;
    final replyTarget = widget.replyTarget;
    final showStop = state.canStop;
    final hintText = state.isEditing
        ? 'Zakończ edycję wiadomości w historii, aby wrócić do composera...'
        : replyTarget == null
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              IgnorePointer(
                ignoring: state.isEditing,
                child: Opacity(
                  opacity: state.isEditing ? 0.45 : 1,
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
                    enabled: !state.isEditing,
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
        ],
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
