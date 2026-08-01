import 'package:tt_mail_assistant/domain/entities/sentiment_result.dart';

abstract class SentimentRepository {
  Future<SentimentResult> analyze(String text);
}
