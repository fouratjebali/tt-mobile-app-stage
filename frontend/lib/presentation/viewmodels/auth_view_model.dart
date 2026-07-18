import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tt_mail_assistant/domain/entities/app_user.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';

enum AuthStatus {
  idle,
  checking,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authUseCase);

  final AuthUseCase _authUseCase;

  AuthStatus status = AuthStatus.idle;
  AppUser? user;
  String? errorMessage;

  Future<void> prepareSignIn() async {
    try {
      await _authUseCase.prepareSignIn();
    } catch (_) {
      // Interactive sign-in will surface any configuration errors.
    }
  }

  Future<AppUser?> checkSession() async {
    status = AuthStatus.checking;
    notifyListeners();

    user = await _authUseCase.getCurrentUser();
    status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
    return user;
  }

  Future<AppUser?> signIn() async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _authUseCase.signIn();
      status = AuthStatus.authenticated;
      notifyListeners();
      return user;
    } on GoogleSignInException catch (error) {
      errorMessage = _messageForGoogleError(error);
      status = AuthStatus.error;
      notifyListeners();
      return null;
    } on BackendAuthException catch (error) {
      errorMessage = error.message;
      status = AuthStatus.error;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Unable to sign in. Please try again.';
      status = AuthStatus.error;
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    await _authUseCase.signOut();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _messageForGoogleError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in is not available on this device.';
      default:
        return error.description ?? 'Google sign-in failed.';
    }
  }
}
