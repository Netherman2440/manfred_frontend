import 'edit_target.dart';
import 'pending_attachment.dart';
import 'queued_message.dart';

class ComposerState {
  const ComposerState({
    required this.draft,
    required this.isSending,
    required this.isStreaming,
    required this.isStopping,
    required this.errorMessage,
    required this.pendingUserMessage,
    required this.pendingUserAttachments,
    required this.streamingText,
    required this.activeSessionId,
    required this.activeAgentId,
    required this.activeAgentName,
    required this.streamingStartedAt,
    required this.attachments,
    required this.editTarget,
    required this.pendingQueuedMessages,
  });

  const ComposerState.initial()
    : draft = '',
      isSending = false,
      isStreaming = false,
      isStopping = false,
      errorMessage = null,
      pendingUserMessage = null,
      pendingUserAttachments = const <PendingAttachment>[],
      streamingText = '',
      activeSessionId = null,
      activeAgentId = null,
      activeAgentName = null,
      streamingStartedAt = null,
      attachments = const <PendingAttachment>[],
      editTarget = null,
      pendingQueuedMessages = const <QueuedMessage>[];

  final String draft;
  final bool isSending;
  final bool isStreaming;
  final bool isStopping;
  final String? errorMessage;
  final String? pendingUserMessage;
  final List<PendingAttachment> pendingUserAttachments;
  final String streamingText;
  final String? activeSessionId;
  final String? activeAgentId;
  final String? activeAgentName;
  final DateTime? streamingStartedAt;
  final List<PendingAttachment> attachments;
  final EditTarget? editTarget;
  final List<QueuedMessage> pendingQueuedMessages;

  bool get isBusy => isSending || isStopping;

  bool get canStop => isStreaming && activeSessionId != null && !isStopping;

  bool get isEditing => editTarget != null;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get hasQueuedMessages => pendingQueuedMessages.isNotEmpty;

  ComposerState copyWith({
    String? draft,
    bool? isSending,
    bool? isStreaming,
    bool? isStopping,
    String? errorMessage,
    String? pendingUserMessage,
    List<PendingAttachment>? pendingUserAttachments,
    String? streamingText,
    String? activeSessionId,
    String? activeAgentId,
    String? activeAgentName,
    DateTime? streamingStartedAt,
    List<PendingAttachment>? attachments,
    EditTarget? editTarget,
    List<QueuedMessage>? pendingQueuedMessages,
    bool clearErrorMessage = false,
    bool clearPendingUserMessage = false,
    bool clearPendingUserAttachments = false,
    bool clearStreamingText = false,
    bool clearActiveRun = false,
    bool clearAttachments = false,
    bool clearEditTarget = false,
  }) {
    return ComposerState(
      draft: draft ?? this.draft,
      isSending: isSending ?? this.isSending,
      isStreaming: isStreaming ?? this.isStreaming,
      isStopping: isStopping ?? this.isStopping,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      pendingUserMessage: clearPendingUserMessage
          ? null
          : pendingUserMessage ?? this.pendingUserMessage,
      pendingUserAttachments: clearPendingUserAttachments
          ? const <PendingAttachment>[]
          : pendingUserAttachments ?? this.pendingUserAttachments,
      streamingText: clearStreamingText
          ? ''
          : streamingText ?? this.streamingText,
      activeSessionId: clearActiveRun
          ? null
          : activeSessionId ?? this.activeSessionId,
      activeAgentId: clearActiveRun
          ? null
          : activeAgentId ?? this.activeAgentId,
      activeAgentName: clearActiveRun
          ? null
          : activeAgentName ?? this.activeAgentName,
      streamingStartedAt: clearActiveRun
          ? null
          : streamingStartedAt ?? this.streamingStartedAt,
      attachments: clearAttachments
          ? const <PendingAttachment>[]
          : attachments ?? this.attachments,
      editTarget: clearEditTarget ? null : editTarget ?? this.editTarget,
      pendingQueuedMessages:
          pendingQueuedMessages ?? this.pendingQueuedMessages,
    );
  }
}
