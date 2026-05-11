class ApiError implements Exception {
  const ApiError({required this.message, this.statusCode, this.details});

  final String message;
  final int? statusCode;

  /// Decoded JSON body when available — lets callers recover structured
  /// data such as FastAPI 422 validation details that don't fit the
  /// flattened `message` string.
  final Object? details;

  @override
  String toString() => message;
}
