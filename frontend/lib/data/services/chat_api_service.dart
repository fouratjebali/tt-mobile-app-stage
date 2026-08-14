import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent_event.dart';

class ChatApiService {
  final String baseUrl;

  ChatApiService({
    required this.baseUrl,
  });

  Stream<AgentEvent> sendMessageStream({
    required String message,
    required List<Map<String, String>> conversationHistory,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/chat'),
    );

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';

    request.body = jsonEncode({
      'message': message,
      'conversation_history': conversationHistory,
    });

    final response = await request.send();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Erreur backend: ${response.statusCode}',
      );
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');

      for (final line in lines) {
        if (!line.startsWith('data:')) {
          continue;
        }

        final data = line.substring(5).trim();

        if (data.isEmpty) {
          continue;
        }

        try {
          final json = jsonDecode(data);

          yield AgentEvent.fromJson(
            json as Map<String, dynamic>,
          );
        } catch (_) {
          // Ignore malformed SSE events.
        }
      }
    }
  }
}