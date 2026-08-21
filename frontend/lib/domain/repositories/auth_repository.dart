import 'package:tt_mail_assistant/domain/entities/app_user.dart';

abstract class AuthRepository {
  Future<void> prepareSignIn();

  Future<AppUser?> getCurrentUser();

  Future<AppUser> signIn();

  Future<void> signOut();
}
