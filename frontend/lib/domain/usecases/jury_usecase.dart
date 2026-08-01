import 'package:tt_mail_assistant/domain/entities/jury_verdict.dart';
import 'package:tt_mail_assistant/domain/repositories/jury_repository.dart';

class JuryUseCase {
  const JuryUseCase(this._repository);

  final JuryRepository _repository;

  Future<JuryVerdict> verify({
    required Map<String, dynamic> email,
    required Map<String, dynamic> analysis,
    required Map<String, dynamic> agentResponse,
  }) {
    return _repository.verify(
      email: email,
      analysis: analysis,
      agentResponse: agentResponse,
    );
  }
}
