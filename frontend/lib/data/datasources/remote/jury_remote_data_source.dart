import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/jury_verdict.dart';

class JuryRemoteDataSource {
  const JuryRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<JuryVerdict> verify({
    required Map<String, dynamic> email,
    required Map<String, dynamic> analysis,
    required Map<String, dynamic> agentResponse,
  }) async {
    final payload = await _apiService.post(
      '/jury/verify',
      body: {
        'email': email,
        'analysis': analysis,
        'agent_response': agentResponse,
      },
    );

    return JuryVerdict(
      verdict: payload['verdict'] as String,
      confidenceScore: (payload['confidenceScore'] as num).toDouble(),
      comment: payload['comment'] as String,
    );
  }
}
