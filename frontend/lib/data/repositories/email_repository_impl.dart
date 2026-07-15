import 'package:frontend/data/datasources/remote/api_service.dart';
import 'package:frontend/domain/entities/email.dart';
import 'package:frontend/domain/repositories/email_repository.dart';

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
}

