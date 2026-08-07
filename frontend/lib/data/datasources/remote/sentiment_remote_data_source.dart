import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/sentiment_result.dart';

class SentimentRemoteDataSource {
  const SentimentRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<SentimentResult> analyze(String text) async {
    final payload = await _apiService.post(
      '/sentiment/analyze',
      body: {'text': text},
    );

    return SentimentResult(
      text: payload['text'] as String,
      label: payload['label'] as String,
      score: (payload['score'] as num).toDouble(),
      rawScores: payload['raw_scores'] as Map<String, dynamic>,
    );
  }
}
