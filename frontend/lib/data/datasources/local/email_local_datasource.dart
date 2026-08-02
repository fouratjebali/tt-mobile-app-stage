import 'package:tt_mail_assistant/domain/entities/email.dart';

abstract class EmailLocalDataSource {
  Future<void> saveEmails(List<Email> emails);

  Future<void> saveEmail(Email email);

  Future<List<Email>> getEmails();

  Future<List<Email>> getTodayEmails();

  Future<List<Email>> getReviewEmails();

  Future<Email?> getEmailById(String id);

  Future<void> markAsRead(String id);
}