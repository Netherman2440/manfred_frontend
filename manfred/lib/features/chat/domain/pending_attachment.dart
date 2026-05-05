import 'dart:typed_data';

import '../../sessions/domain/session_attachment.dart';

class PendingAttachment {
  const PendingAttachment({
    required this.localId,
    required this.fileName,
    required this.mediaType,
    required this.sizeBytes,
    this.attachmentId,
    this.localPath,
    this.bytes,
    this.remotePath,
  });

  final String localId;
  final String fileName;
  final String mediaType;
  final int sizeBytes;
  final String? attachmentId;
  final String? localPath;
  final Uint8List? bytes;
  final String? remotePath;

  bool get isExisting => attachmentId != null && attachmentId!.isNotEmpty;

  SessionAttachment toSessionAttachment() {
    return SessionAttachment(
      id: attachmentId ?? localId,
      fileName: fileName,
      mediaType: mediaType,
      sizeBytes: sizeBytes,
      path: remotePath ?? localPath ?? '',
    );
  }

  PendingAttachment copyWith({
    String? localId,
    String? fileName,
    String? mediaType,
    int? sizeBytes,
    String? attachmentId,
    String? localPath,
    Uint8List? bytes,
    String? remotePath,
    bool clearAttachmentId = false,
    bool clearLocalPath = false,
    bool clearBytes = false,
    bool clearRemotePath = false,
  }) {
    return PendingAttachment(
      localId: localId ?? this.localId,
      fileName: fileName ?? this.fileName,
      mediaType: mediaType ?? this.mediaType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      attachmentId: clearAttachmentId
          ? null
          : attachmentId ?? this.attachmentId,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      bytes: clearBytes ? null : bytes ?? this.bytes,
      remotePath: clearRemotePath ? null : remotePath ?? this.remotePath,
    );
  }

  factory PendingAttachment.fromSessionAttachment(SessionAttachment value) {
    return PendingAttachment(
      localId: value.id,
      attachmentId: value.id,
      fileName: value.fileName,
      mediaType: value.mediaType,
      sizeBytes: value.sizeBytes,
      remotePath: value.path,
    );
  }
}
