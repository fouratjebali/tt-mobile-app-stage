import 'dart:convert';

import 'package:tt_mail_assistant/core/errors/error_message.dart';
import 'package:http/http.dart' as http;
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';

class ApiServiceImpl {
  ApiServiceImpl({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    final response = await _client.get(_uri(path), headers: headers);
    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: ErrorMessage.fromApi(
        statusCode: response.statusCode,
        message: _responseMessage(response),
      ),
    );
  }

  String _responseMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    } catch (_) {
      // Fall back to the raw response body below.
    }

    return response.body;
  }
}
