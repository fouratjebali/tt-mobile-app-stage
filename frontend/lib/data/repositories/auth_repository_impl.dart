import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthSecureStorage secureStorage,
    required GoogleAuthDataSource googleAuthDataSource,
    required BackendAuthDataSource backendAuthDataSource,
  }) : _secureStorage = secureStorage,
       _googleAuthDataSource = googleAuthDataSource,
       _backendAuthDataSource = backendAuthDataSource;

  final AuthSecureStorage _secureStorage;
  final GoogleAuthDataSource _googleAuthDataSource;
  final BackendAuthDataSource _backendAuthDataSource;

  @override
  Future<void> prepareSignIn() => _googleAuthDataSource.prepareSignIn();

  @override
  Future<AppUser?> getCurrentUser() => _secureStorage.readUser();

  @override
  Future<AppUser> signInWithGoogle() async {
    final googleSession = await _googleAuthDataSource.signIn();
    final session = await _backendAuthDataSource.signInWithGoogle(
      googleSession,
    );
    await _secureStorage.saveSession(session);
    return session.user;
  }

  @override
  Future<void> signOut() async {
    await _googleAuthDataSource.signOut();
    await _secureStorage.clear();
  }
}
