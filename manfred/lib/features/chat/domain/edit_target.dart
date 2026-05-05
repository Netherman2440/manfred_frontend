import 'pending_attachment.dart';

class EditTarget {
  const EditTarget({
    required this.sessionId,
    required this.itemId,
    required this.originalMessage,
    required this.originalSequence,
    required this.draft,
    required this.attachments,
  });

  final String sessionId;
  final String itemId;
  final String originalMessage;
  final int originalSequence;
  final String draft;
  final List<PendingAttachment> attachments;

  EditTarget copyWith({
    String? sessionId,
    String? itemId,
    String? originalMessage,
    int? originalSequence,
    String? draft,
    List<PendingAttachment>? attachments,
  }) {
    return EditTarget(
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      originalMessage: originalMessage ?? this.originalMessage,
      originalSequence: originalSequence ?? this.originalSequence,
      draft: draft ?? this.draft,
      attachments: attachments ?? this.attachments,
    );
  }
}
