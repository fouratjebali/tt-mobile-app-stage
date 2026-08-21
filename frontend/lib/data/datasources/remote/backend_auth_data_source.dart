import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class BackendAuthDataSource {
  BackendAuthDataSource(this._apiService);

  final ApiService _apiService;

  Future<AppUser> currentUser() async {
    final payload = await _apiService.get('/auth/me');
    return _userFromPayload(payload);
  }

  Future<AuthSession> signInWithMicrosoft(AuthSession microsoftSession) async {
    final payload = await _apiService.post(
      '/auth/microsoft',
      authenticated: false,
      body: {
        'access_token': microsoftSession.accessToken,
        'id_token': microsoftSession.idToken,
        'refresh_token': microsoftSession.refreshToken,
        'expires_at': microsoftSession.expiresAt?.toIso8601String(),
      },
    );
    final userPayload = payload['user'] as Map<String, dynamic>;

    return AuthSession(
      user: _userFromPayload(userPayload),
      accessToken: microsoftSession.accessToken,
      backendToken: payload['session_token'] as String,
      idToken: microsoftSession.idToken,
      refreshToken: microsoftSession.refreshToken,
      expiresAt:
          payload['expires_at'] == null
              ? null
              : DateTime.parse(payload['expires_at'] as String),
    );
  }

  AppUser _userFromPayload(Map<String, dynamic> payload) {
    return AppUser(
      id: payload['id'] as String,
      email: payload['email'] as String,
      displayName: payload['display_name'] as String?,
      photoUrl: payload['photo_url'] as String?,
    );
  }
}
