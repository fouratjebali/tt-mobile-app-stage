import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bulk_email.dart';
import '../models/bulk_email_result.dart';

class BulkEmailApiService {
  final String baseUrl;

  BulkEmailApiService({required this.baseUrl});

  Future<List<BulkEmail>> generateEmails({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bulk/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recipients': recipients,
        'topic': topic,
        'instructions': instructions,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Generation failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    final List<dynamic> emails = data['details'] ?? data['emails'] ?? [];

    return emails
        .map((email) => BulkEmail.fromJson(email as Map<String, dynamic>))
        .toList();
  }

  Future<List<BulkEmailResult>> sendAll({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bulk/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recipients': recipients,
        'topic': topic,
        'instructions': instructions,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Send failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    final List<dynamic> results = data['details'] ?? data['results'] ?? [];

    return results
        .map(
          (result) => BulkEmailResult.fromJson(result as Map<String, dynamic>),
        )
        .toList();
  }
}
