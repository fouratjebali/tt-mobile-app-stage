import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bulk_email.dart';
import '../models/bulk_email_result.dart';

class BulkEmailApiService {
  final String baseUrl;

  BulkEmailApiService({
    required this.baseUrl,
  });

  Future<List<BulkEmail>> generateEmails({
    required List<String> recipients,
    required String topic,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/bulk-email/generate'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'recipients': recipients,
        'topic': topic,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Generation failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    final List<dynamic> emails = data['emails'] ?? [];

    return emails
        .map(
          (email) => BulkEmail.fromJson(
        email as Map<String, dynamic>,
      ),
    )
        .toList();
  }

  Future<BulkEmail> editGenerated({
    required String id,
    required String newBody,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/bulk-email/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'body': newBody,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Edit failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    return BulkEmail.fromJson(
      data as Map<String, dynamic>,
    );
  }

  Future<List<BulkEmailResult>> sendAll({
    required List<BulkEmail> emails,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/bulk-email/send-all'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'emails': emails.map((email) => email.toJson()).toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Send failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    final List<dynamic> results = data['results'] ?? [];

    return results
        .map(
          (result) => BulkEmailResult.fromJson(
        result as Map<String, dynamic>,
      ),
    )
        .toList();
  }
}