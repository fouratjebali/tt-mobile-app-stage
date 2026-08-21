import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/outlook_auth_data_source.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthSecureStorage secureStorage,
    required OutlookAuthDataSource outlookAuthDataSource,
    required BackendAuthDataSource backendAuthDataSource,
  }) : _secureStorage = secureStorage,
       _outlookAuthDataSource = outlookAuthDataSource,
       _backendAuthDataSource = backendAuthDataSource;

  final AuthSecureStorage _secureStorage;
  final OutlookAuthDataSource _outlookAuthDataSource;
  final BackendAuthDataSource _backendAuthDataSource;

  @override
  Future<void> prepareSignIn() => _outlookAuthDataSource.prepareSignIn();

  @override
  Future<AppUser?> getCurrentUser() async {
    final localUser = await _secureStorage.readUser();
    if (localUser == null) return null;

    try {
      return await _backendAuthDataSource.currentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 410) {
        await _secureStorage.clear();
        return null;
      }
      return localUser;
    }
  }

  @override
  Future<AppUser> signIn() async {
    final outlookSession = await _outlookAuthDataSource.signIn();
    final session = await _backendAuthDataSource.signInWithMicrosoft(
      outlookSession,
    );
    await _secureStorage.saveSession(session);
    return session.user;
  }

  @override
  Future<void> signOut() async {
    await _outlookAuthDataSource.signOut();
    await _secureStorage.clear();
  }
}
