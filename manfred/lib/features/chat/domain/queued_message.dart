import 'pending_attachment.dart';

class QueuedMessage {
  const QueuedMessage({
    required this.localId,
    required this.sessionId,
    required this.message,
    required this.attachments,
    required this.queuedAt,
    this.queuedInputId,
    this.position,
  });

  final String localId;
  final String sessionId;
  final String message;
  final List<PendingAttachment> attachments;
  final DateTime queuedAt;
  final String? queuedInputId;
  final int? position;

  QueuedMessage copyWith({
    String? localId,
    String? sessionId,
    String? message,
    List<PendingAttachment>? attachments,
    DateTime? queuedAt,
    String? queuedInputId,
    int? position,
  }) {
    return QueuedMessage(
      localId: localId ?? this.localId,
      sessionId: sessionId ?? this.sessionId,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      queuedAt: queuedAt ?? this.queuedAt,
      queuedInputId: queuedInputId ?? this.queuedInputId,
      position: position ?? this.position,
    );
  }
}
