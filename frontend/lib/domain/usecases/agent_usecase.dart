import 'package:tt_mail_assistant/domain/repositories/agent_repository.dart';

class AgentUseCase {
  const AgentUseCase(this._repository);

  final AgentRepository _repository;

  Future<String> chat(String message) => _repository.chat(message);
}
