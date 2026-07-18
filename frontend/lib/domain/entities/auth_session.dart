import 'package:tt_mail_assistant/domain/entities/app_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.backendToken,
    this.idToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AppUser user;
  final String accessToken;
  final String? backendToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime? expiresAt;
}
