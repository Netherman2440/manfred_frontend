import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_error.dart';
import 'sse_client.dart';

class ManfredApiClient {
  ManfredApiClient({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(
      _buildUri(path),
      headers: const <String, String>{'Accept': 'application/json'},
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
  }) async {
    return sendJson('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
  }) async {
    return sendJson('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> sendJson(
    String method,
    String path, {
    required Map<String, Object?> body,
  }) async {
    final request = http.Request(method, _buildUri(path));
    request.headers.addAll(const <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode(body);

    final response = await _client.send(request);
    final flattened = await http.Response.fromStream(response);
    return _decodeResponse(flattened);
  }

  Stream<SseMessage> postSse(
    String path, {
    required Map<String, Object?> body,
  }) async* {
    yield* sendSse('POST', path, body: body);
  }

  Stream<SseMessage> patchSse(
    String path, {
    required Map<String, Object?> body,
  }) async* {
    yield* sendSse('PATCH', path, body: body);
  }

  Stream<SseMessage> sendSse(
    String method,
    String path, {
    required Map<String, Object?> body,
  }) async* {
    final request = http.Request(method, _buildUri(path));
    request.headers.addAll(const <String, String>{
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode(body);

    final response = await _client.send(request);
    yield* _decodeSseResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async {
    return sendMultipart('POST', path, fields: fields, files: files);
  }

  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async {
    return sendMultipart('PATCH', path, fields: fields, files: files);
  }

  Future<Map<String, dynamic>> sendMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async {
    final request = http.MultipartRequest(method, _buildUri(path));
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    request.files.addAll(await _buildMultipartFiles(files));

    final response = await _client.send(request);
    final flattened = await http.Response.fromStream(response);
    return _decodeResponse(flattened);
  }

  Stream<SseMessage> postMultipartSse(
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async* {
    yield* sendMultipartSse('POST', path, fields: fields, files: files);
  }

  Stream<SseMessage> patchMultipartSse(
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async* {
    yield* sendMultipartSse('PATCH', path, fields: fields, files: files);
  }

  Stream<SseMessage> sendMultipartSse(
    String method,
    String path, {
    required Map<String, String> fields,
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
  }) async* {
    final request = http.MultipartRequest(method, _buildUri(path));
    request.headers['Accept'] = 'text/event-stream';
    request.fields.addAll(fields);
    request.files.addAll(await _buildMultipartFiles(files));

    final response = await _client.send(request);
    yield* _decodeSseResponse(response);
  }

  Future<List<http.MultipartFile>> _buildMultipartFiles(
    List<ApiMultipartFile> files,
  ) async {
    final result = <http.MultipartFile>[];
    for (final file in files) {
      final mediaType = file.mediaType == null
          ? null
          : MediaType.parse(file.mediaType!);
      if (file.bytes != null) {
        result.add(
          http.MultipartFile.fromBytes(
            file.fieldName,
            file.bytes!,
            filename: file.fileName,
            contentType: mediaType,
          ),
        );
        continue;
      }

      final filePath = file.filePath;
      if (filePath == null || filePath.isEmpty) {
        throw const ApiError(message: 'Attachment is missing file contents.');
      }

      result.add(
        await http.MultipartFile.fromPath(
          file.fieldName,
          filePath,
          filename: file.fileName,
          contentType: mediaType,
        ),
      );
    }

    return result;
  }

  Stream<SseMessage> _decodeSseResponse(http.StreamedResponse response) async* {
    if (response.statusCode >= 400) {
      final responseBody = (await response.stream.bytesToString()).trim();
      final decodedBody = _tryDecodeJson(responseBody);
      throw ApiError(
        message: _extractErrorMessage(
          decodedBody: decodedBody,
          responseBody: responseBody,
          statusCode: response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    yield* const SseMessageParser().bind(
      response.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final responseBody = response.body.trim();
    final decodedBody = _tryDecodeJson(responseBody);

    if (response.statusCode >= 400) {
      throw ApiError(
        message: _extractErrorMessage(
          decodedBody: decodedBody,
          responseBody: responseBody,
          statusCode: response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    if (decodedBody is! Map<String, dynamic>) {
      throw const ApiError(message: 'Backend returned an unexpected response.');
    }

    return decodedBody;
  }

  Object? _tryDecodeJson(String responseBody) {
    if (responseBody.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      return jsonDecode(responseBody);
    } on FormatException {
      return null;
    }
  }

  String _extractErrorMessage({
    required Object? decodedBody,
    required String responseBody,
    required int statusCode,
  }) {
    if (decodedBody is Map<String, dynamic>) {
      final detail = decodedBody['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      final error = decodedBody['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }

    if (responseBody.isNotEmpty) {
      return 'Request failed (HTTP $statusCode).';
    }

    return 'Request failed (HTTP $statusCode).';
  }

  static String _normalizeBaseUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }

    return value;
  }
}

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.fieldName,
    required this.fileName,
    this.mediaType,
    this.bytes,
    this.filePath,
  });

  final String fieldName;
  final String fileName;
  final String? mediaType;
  final Uint8List? bytes;
  final String? filePath;
}
