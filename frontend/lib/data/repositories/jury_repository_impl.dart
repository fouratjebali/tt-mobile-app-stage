import 'package:tt_mail_assistant/data/datasources/remote/jury_remote_data_source.dart';
import 'package:tt_mail_assistant/domain/entities/jury_verdict.dart';
import 'package:tt_mail_assistant/domain/repositories/jury_repository.dart';

class JuryRepositoryImpl implements JuryRepository {
  const JuryRepositoryImpl(this._remoteDataSource);

  final JuryRemoteDataSource _remoteDataSource;

  @override
  Future<JuryVerdict> verify({
    required Map<String, dynamic> email,
    required Map<String, dynamic> analysis,
    required Map<String, dynamic> agentResponse,
  }) {
    return _remoteDataSource.verify(
      email: email,
      analysis: analysis,
      agentResponse: agentResponse,
    );
  }
}
