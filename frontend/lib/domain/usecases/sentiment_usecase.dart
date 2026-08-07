import 'package:tt_mail_assistant/domain/entities/sentiment_result.dart';
import 'package:tt_mail_assistant/domain/repositories/sentiment_repository.dart';

class SentimentUseCase {
  const SentimentUseCase(this._repository);

  final SentimentRepository _repository;

  Future<SentimentResult> analyze(String text) => _repository.analyze(text);
}
