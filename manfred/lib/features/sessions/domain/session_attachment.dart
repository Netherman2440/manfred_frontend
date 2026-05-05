class SessionAttachment {
  const SessionAttachment({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.sizeBytes,
    required this.path,
  });

  final String id;
  final String fileName;
  final String mediaType;
  final int sizeBytes;
  final String path;
}
