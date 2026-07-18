import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';

class AuthUseCase {
  const AuthUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> prepareSignIn() => _repository.prepareSignIn();

  Future<AppUser?> getCurrentUser() => _repository.getCurrentUser();

  Future<AppUser> signIn() => _repository.signInWithGoogle();

  Future<void> signOut() => _repository.signOut();
}
