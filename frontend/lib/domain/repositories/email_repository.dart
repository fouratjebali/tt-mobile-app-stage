import 'package:tt_mail_assistant/domain/entities/email.dart';

abstract class EmailRepository {
  Future<List<Email>> getEmails();
  Future<void> sendReply({required String emailId, required String body});
  Future<void> validateAndSend({required String emailId, required String body});
  Future<void> editAndSend({required String emailId, required String body});
  Future<void> reject({required String emailId});
  Future<Email> getEmailDetails({required String emailId});

  Future<List<Email>> getTodayEmails();
  Future<List<Email>> getReviewRequiredEmails();
  Future<void> markAsRead(String id);
  Future<Email?> getEmailById(String id);

  Future<Map<String, dynamic>> getDashboardStats({required String period});
  Future<Map<String, dynamic>> exportDashboardReport({required String period});
}
