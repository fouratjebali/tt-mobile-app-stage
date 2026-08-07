import 'package:tt_mail_assistant/data/datasources/remote/agent_remote_data_source.dart';
import 'package:tt_mail_assistant/domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  const AgentRepositoryImpl(this._remoteDataSource);

  final AgentRemoteDataSource _remoteDataSource;

  @override
  Future<String> chat(String message) => _remoteDataSource.chat(message);
}
