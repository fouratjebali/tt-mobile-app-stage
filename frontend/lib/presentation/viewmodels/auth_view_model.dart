import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/outlook_auth_data_source.dart';
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
    } on OutlookAuthException catch (error) {
      errorMessage = error.message;
      status = AuthStatus.error;
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = AuthStatus.error;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Unable to sign in with Outlook. Please try again.';
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
}
