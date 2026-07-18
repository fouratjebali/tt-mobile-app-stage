import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class BackendAuthDataSource {
  BackendAuthDataSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  static const _requestTimeout = Duration(seconds: 12);

  Future<AuthSession> signInWithGoogle(AuthSession googleSession) async {
    late final http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/google'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_token': googleSession.accessToken,
              'id_token': googleSession.idToken,
              'refresh_token': googleSession.refreshToken,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const BackendAuthException(
        'Backend is taking too long to respond. Check Docker and try again.',
      );
    } on http.ClientException {
      throw const BackendAuthException(
        'Cannot reach the backend. Make sure Docker is running.',
      );
    }

    if (response.statusCode != 200) {
      throw BackendAuthException(_errorMessage(response));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
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

  String _errorMessage(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Fall back to a generic message below.
    }

    return 'Backend authentication failed.';
  }
}

class BackendAuthException implements Exception {
  const BackendAuthException(this.message);

  final String message;
}
