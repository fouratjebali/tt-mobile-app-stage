import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/entities/auth_session.dart';

class GoogleAuthDataSource {
  GoogleAuthDataSource({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  bool _isInitialized = false;

  static const gmailScopes = <String>[
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.modify',
  ];

  Future<void> prepareSignIn() => _initialize();

  Future<AuthSession> signIn() async {
    await _initialize();

    final account = await _googleSignIn.authenticate(scopeHint: gmailScopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(gmailScopes) ??
        await account.authorizationClient.authorizeScopes(gmailScopes);

    debugPrint(
      'Google authorization granted for Gmail scopes: ${authorization.accessToken.isNotEmpty}',
    );

    final user = AppUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );

    return AuthSession(
      user: user,
      accessToken: authorization.accessToken,
      idToken: account.authentication.idToken,
    );
  }

  Future<void> signOut() async {
    await _initialize();
    await _googleSignIn.signOut();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    const clientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
    const serverClientId = String.fromEnvironment(
      'GOOGLE_OAUTH_SERVER_CLIENT_ID',
    );

    await _googleSignIn.initialize(
      clientId: clientId.isEmpty ? null : clientId,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _isInitialized = true;
  }
}
