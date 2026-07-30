import 'package:tt_mail_assistant/domain/entities/email.dart';

abstract class EmailRepository {
  Future<List<Email>> getEmails();
  Future<void> sendReply({required String emailId, required String body});
  Future<Email> getEmailDetails({required String emailId});

  // --- AJOUT pour la carte "Domain layer -- Email module" ---
  Future<List<Email>> getTodayEmails();
  Future<List<Email>> getReviewRequiredEmails();
  Future<Email?> getEmailById(String id);
}