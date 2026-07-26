import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/repositories/email_repository.dart';

class EmailUseCase {
  const EmailUseCase(this._repository);

  final EmailRepository _repository;

  Future<List<Email>> getEmails() => _repository.getEmails();

  Future<Email> getEmailDetails({required String emailId}) =>
      _repository.getEmailDetails(emailId: emailId);

  Future<void> sendReply({required String emailId, required String body}) =>
      _repository.sendReply(emailId: emailId, body: body);
}