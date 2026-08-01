import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';

class ApiService {
  ApiService({
    required AuthSecureStorage secureStorage,
    http.Client? client,
    String? baseUrl,
  }) : _secureStorage = secureStorage,
       _client = client ?? http.Client(),
       _baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://10.0.2.2:8000/api/v1',
           );

  final AuthSecureStorage _secureStorage;
  final http.Client _client;
  final String _baseUrl;

  static const requestTimeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => _client.get(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => _client.post(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
    );

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      () async => _client.delete(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
    );

    return _decodeMap(response);
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await _secureStorage.readBackendToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    late final http.Response response;

    try {
      response = await request().timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Backend is taking too long to respond. Check Docker and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the backend. Make sure Docker is running.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response));
    }

    return response;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};

    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic>) return payload;

    throw const ApiException('Backend returned an unexpected response.');
  }

  String _errorMessage(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Fall back to a generic message below.
    }

    return 'Backend request failed.';
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;
}
