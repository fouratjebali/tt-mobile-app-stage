import 'package:tt_mail_assistant/domain/entities/email.dart';

abstract class EmailRepository {
  Future<List<Email>> getEmails();
  Future<void> sendReply({required String emailId, required String body});
  Future<void> validateAndSend({required String emailId, required String body});
  Future<void> editAndSend({required String emailId, required String body});
  Future<void> reject({required String emailId});
  Future<Email> getEmailDetails({required String emailId});

  // --- AJOUT pour la carte "Domain layer -- Email module" ---
  Future<List<Email>> getTodayEmails();
  Future<List<Email>> getReviewRequiredEmails();
  Future<void> markAsRead(String id);
  Future<Email?> getEmailById(String id);
}
