import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_error.dart';

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
    final response = await _client.post(
      _buildUri(path),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
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
