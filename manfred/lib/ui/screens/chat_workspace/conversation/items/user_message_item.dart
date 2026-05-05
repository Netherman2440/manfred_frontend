import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/agent_avatar.dart';
import '../../../../core/hover_tile_container.dart';
import '../../../../mock/manfred_mock_data.dart';
import '../../../../theme/manfred_theme.dart';
import 'conversation_entry_header.dart';

class UserMessageItem extends StatefulWidget {
  const UserMessageItem({
    super.key,
    required this.entry,
    this.onEdit,
    this.onEditChanged,
    this.onCancelEdit,
    this.onSaveEdit,
  });

  final UserConversationEntryMock entry;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onEditChanged;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onSaveEdit;

  @override
  State<UserMessageItem> createState() => _UserMessageItemState();
}

class _UserMessageItemState extends State<UserMessageItem> {
  late final TextEditingController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entry.editingDraft ?? '');
  }

  @override
  void didUpdateWidget(covariant UserMessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDraft = widget.entry.editingDraft ?? '';
    if (_controller.text == nextDraft) {
      return;
    }

    _controller.value = TextEditingValue(
      text: nextDraft,
      selection: TextSelection.collapsed(offset: nextDraft.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;

    return HoverTileContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onHoverChanged: (value) {
        if (_isHovered == value) {
          return;
        }
        setState(() => _isHovered = value);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AgentAvatar(
            label: _avatarLabel(entry.author),
            accentColor: ManfredColors.accentBlue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConversationEntryHeader(
                  author: entry.author,
                  dateLabel: entry.dateLabel,
                  timeLabel: entry.timeLabel,
                  authorColor: ManfredColors.accentBlue,
                ),
                if (!entry.isEdited && entry.pendingStatus != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (entry.pendingStatus != null)
                        _StatusChip(
                          label: entry.pendingStatus == 'queued'
                              ? 'Queued'
                              : 'Sending',
                          color: entry.pendingStatus == 'queued'
                              ? ManfredColors.accentAmber
                              : ManfredColors.accentBlue,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (entry.isEditing)
                  _InlineEditor(
                    controller: _controller,
                    isSaving: entry.isSavingEdit,
                    onChanged: widget.onEditChanged,
                    onCancel: widget.onCancelEdit,
                    onSave: widget.onSaveEdit,
                  )
                else
                  SelectableText(entry.body, style: textTheme.bodyMedium),
                if (entry.attachments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.attachments
                        .map(
                          (attachment) =>
                              _AttachmentChip(attachment: attachment),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          if (!entry.isEditing && widget.onEdit != null) ...<Widget>[
            const SizedBox(width: 12),
            SizedBox(
              width: 32,
              height: 32,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: _isHovered
                    ? Tooltip(
                        key: const ValueKey('edit-action'),
                        message: 'Edit message',
                        child: IconButton(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                          color: ManfredColors.textSecondary,
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('edit-action-hidden'),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _avatarLabel(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }
}

class _InlineEditor extends StatelessWidget {
  const _InlineEditor({
    required this.controller,
    required this.isSaving,
    this.onChanged,
    this.onCancel,
    this.onSave,
  });

  final TextEditingController controller;
  final bool isSaving;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = !isSaving && controller.text.trim().isNotEmpty;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!isSaving) {
            onCancel?.call();
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (canSave) {
            onSave?.call();
          }
        },
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller,
            enabled: !isSaving,
            autofocus: true,
            minLines: 1,
            maxLines: 8,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              hintText: 'Edytuj wiadomość...',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: ManfredColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: ManfredColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isSaving
                      ? ManfredColors.accentBlue.withValues(alpha: 0.45)
                      : ManfredColors.accentBlue,
                ),
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isSaving ? 'Zapisywanie...' : 'Esc anuluje, Enter zapisuje',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ManfredColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment});

  final ConversationAttachmentMock attachment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ManfredColors.panelAltBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ManfredColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.attach_file_rounded,
            size: 16,
            color: ManfredColors.textSecondary,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              '${attachment.fileName} · ${_formatSize(attachment.sizeBytes)}',
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}
