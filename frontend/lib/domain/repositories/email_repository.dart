import 'package:tt_mail_assistant/domain/entities/email.dart';

abstract class EmailRepository {
  Future<List<Email>> getEmails();
  Future<void> sendReply({required String emailId, required String body});
  Future<Email> getEmailDetails({required String emailId});
}
