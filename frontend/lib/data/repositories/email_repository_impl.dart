import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/repositories/email_repository.dart';

class EmailRepositoryImpl implements EmailRepository {
  final ApiService apiService;

  EmailRepositoryImpl({required this.apiService});

  @override
  Future<Email> getEmailDetails({required String emailId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Email>> getEmails() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendReply({required String emailId, required String body}) {
    throw UnimplementedError();
  }

  // --- AJOUT : stubs en attendant la vraie intégration API (carte séparée) ---
  @override
  Future<List<Email>> getTodayEmails() {
    throw UnimplementedError();
  }

  @override
  Future<List<Email>> getReviewRequiredEmails() {
    throw UnimplementedError();
  }

  @override
  Future<Email?> getEmailById(String id) {
    throw UnimplementedError();
  }
}