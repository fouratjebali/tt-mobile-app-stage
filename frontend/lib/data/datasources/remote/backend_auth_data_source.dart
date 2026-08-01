import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class BackendAuthDataSource {
  BackendAuthDataSource(this._apiService);

  final ApiService _apiService;

  Future<AuthSession> signInWithGoogle(AuthSession googleSession) async {
    final payload = await _apiService.post(
      '/auth/google',
      authenticated: false,
      body: {
        'access_token': googleSession.accessToken,
        'id_token': googleSession.idToken,
        'refresh_token': googleSession.refreshToken,
      },
    );
    final userPayload = payload['user'] as Map<String, dynamic>;

    return AuthSession(
      user: AppUser(
        id: userPayload['id'] as String,
        email: userPayload['email'] as String,
        displayName: userPayload['display_name'] as String?,
        photoUrl: userPayload['photo_url'] as String?,
      ),
      accessToken: googleSession.accessToken,
      backendToken: payload['session_token'] as String,
      idToken: googleSession.idToken,
      refreshToken: googleSession.refreshToken,
      expiresAt:
          payload['expires_at'] == null
              ? null
              : DateTime.parse(payload['expires_at'] as String),
    );
  }
}
