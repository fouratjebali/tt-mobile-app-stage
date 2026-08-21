import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class OutlookAuthDataSource {
  OutlookAuthDataSource({FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  static const _clientId = String.fromEnvironment('MICROSOFT_CLIENT_ID');
  static const _tenantId = String.fromEnvironment(
    'MICROSOFT_TENANT_ID',
    defaultValue: 'common',
  );
  static const _redirectUri = String.fromEnvironment('MICROSOFT_REDIRECT_URI');

  static const scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    'User.Read',
    'Mail.Read',
    'Mail.ReadWrite',
    'Mail.Send',
  ];

  Future<void> prepareSignIn() async {
    _validateConfig();
  }

  Future<AuthSession> signIn() async {
    _validateConfig();
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUri,
        serviceConfiguration: _serviceConfiguration(),
        scopes: scopes,
        promptValues: const ['select_account'],
      ),
    );

    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OutlookAuthException(
        'Microsoft sign-in did not return an access token.',
      );
    }

    return AuthSession(
      user: const AppUser(id: 'microsoft', email: ''),
      accessToken: accessToken,
      idToken: result.idToken,
      refreshToken: result.refreshToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
  }

  Future<void> signOut() async {}

  AuthorizationServiceConfiguration _serviceConfiguration() {
    final base = 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0';
    return AuthorizationServiceConfiguration(
      authorizationEndpoint: '$base/authorize',
      tokenEndpoint: '$base/token',
      endSessionEndpoint: '$base/logout',
    );
  }

  void _validateConfig() {
    if (_clientId.trim().isEmpty || _redirectUri.trim().isEmpty) {
      throw const OutlookAuthException(
        'Microsoft sign-in is not configured. Check MICROSOFT_CLIENT_ID and MICROSOFT_REDIRECT_URI in .env.',
      );
    }
  }
}

class OutlookAuthException implements Exception {
  const OutlookAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
