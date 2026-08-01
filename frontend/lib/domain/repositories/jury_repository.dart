import 'package:tt_mail_assistant/domain/entities/jury_verdict.dart';

abstract class JuryRepository {
  Future<JuryVerdict> verify({
    required Map<String, dynamic> email,
    required Map<String, dynamic> analysis,
    required Map<String, dynamic> agentResponse,
  });
}
