import 'package:tt_mail_assistant/data/datasources/remote/sentiment_remote_data_source.dart';
import 'package:tt_mail_assistant/domain/entities/sentiment_result.dart';
import 'package:tt_mail_assistant/domain/repositories/sentiment_repository.dart';

class SentimentRepositoryImpl implements SentimentRepository {
  const SentimentRepositoryImpl(this._remoteDataSource);

  final SentimentRemoteDataSource _remoteDataSource;

  @override
  Future<SentimentResult> analyze(String text) {
    return _remoteDataSource.analyze(text);
  }
}
