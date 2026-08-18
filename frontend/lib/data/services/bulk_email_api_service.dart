import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';

import '../models/bulk_email.dart';
import '../models/bulk_email_result.dart';

class BulkEmailApiService {
  BulkEmailApiService({required ApiService apiService})
    : _apiService = apiService;

  final ApiService _apiService;

  Future<List<BulkEmail>> generateEmails({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
  }) async {
    final data = await _apiService.post(
      '/bulk/generate',
      body: {
        'recipients': recipients,
        'topic': topic,
        'instructions': instructions,
      },
    );

    final emails = _listFromResponse(data, 'details', 'emails');

    return emails
        .map((email) => BulkEmail.fromJson(email as Map<String, dynamic>))
        .toList();
  }

  Future<List<BulkEmailResult>> sendAll({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
  }) async {
    final data = await _apiService.post(
      '/bulk/send',
      body: {
        'recipients': recipients,
        'topic': topic,
        'instructions': instructions,
      },
    );

    final results = _listFromResponse(data, 'details', 'results');

    return results
        .map(
          (result) => BulkEmailResult.fromJson(result as Map<String, dynamic>),
        )
        .toList();
  }

  List<dynamic> _listFromResponse(
    dynamic data,
    String primary,
    String fallback,
  ) {
    if (data is Map<String, dynamic>) {
      final value = data[primary] ?? data[fallback];
      if (value is List) return value;
    }
    if (data is Map) {
      final value = data[primary] ?? data[fallback];
      if (value is List) return value;
    }
    return const [];
  }
}
