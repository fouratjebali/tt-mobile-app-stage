import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class AuthSecureStorage {
  const AuthSecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _backendTokenKey = 'backend_session_token';
  static const _idTokenKey = 'id_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'token_expires_at';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userNameKey = 'user_display_name';
  static const _userPhotoKey = 'user_photo_url';

  Future<void> saveSession(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      if (session.backendToken != null)
        _storage.write(key: _backendTokenKey, value: session.backendToken),
      if (session.idToken != null)
        _storage.write(key: _idTokenKey, value: session.idToken),
      if (session.refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      if (session.expiresAt != null)
        _storage.write(
          key: _expiresAtKey,
          value: session.expiresAt!.toIso8601String(),
        ),
      _storage.write(key: _userIdKey, value: session.user.id),
      _storage.write(key: _userEmailKey, value: session.user.email),
      if (session.user.displayName != null)
        _storage.write(key: _userNameKey, value: session.user.displayName),
      if (session.user.photoUrl != null)
        _storage.write(key: _userPhotoKey, value: session.user.photoUrl),
    ]);
  }

  Future<AppUser?> readUser() async {
    final values = await _storage.readAll();
    final token = values[_accessTokenKey];
    final id = values[_userIdKey];
    final email = values[_userEmailKey];

    final backendToken = values[_backendTokenKey];

    if (token == null ||
        token.isEmpty ||
        backendToken == null ||
        backendToken.isEmpty ||
        id == null ||
        email == null) {
      return null;
    }

    return AppUser(
      id: id,
      email: email,
      displayName: values[_userNameKey],
      photoUrl: values[_userPhotoKey],
    );
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readBackendToken() => _storage.read(key: _backendTokenKey);

  Future<void> clear() => _storage.deleteAll();
}
