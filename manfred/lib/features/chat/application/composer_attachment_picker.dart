import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pending_attachment.dart';

abstract class ComposerAttachmentPicker {
  Future<List<PendingAttachment>> pickAttachments();
}

class FilePickerComposerAttachmentPicker implements ComposerAttachmentPicker {
  const FilePickerComposerAttachmentPicker();

  @override
  Future<List<PendingAttachment>> pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) {
      return const <PendingAttachment>[];
    }

    return result.files
        .map(_mapPlatformFile)
        .whereType<PendingAttachment>()
        .toList(growable: false);
  }

  PendingAttachment? _mapPlatformFile(PlatformFile file) {
    final resolvedName = file.name.trim();
    if (resolvedName.isEmpty) {
      return null;
    }

    return PendingAttachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}-$resolvedName',
      fileName: resolvedName,
      mediaType: _resolveMediaType(file),
      sizeBytes: file.size,
      localPath: file.path,
      bytes: file.bytes,
    );
  }

  String _resolveMediaType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };
  }
}

final composerAttachmentPickerProvider = Provider<ComposerAttachmentPicker>((
  ref,
) {
  return const FilePickerComposerAttachmentPicker();
});
