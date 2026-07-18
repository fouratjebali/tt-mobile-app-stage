import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/services/launch_preferences.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/login_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/onboarding_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/inbox/inbox_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNextScreen();
    });
  }

  Future<void> _openNextScreen() async {
    var hasSeenOnboarding = false;
    Object? currentUser;

    await Future.wait<void>([
      LaunchPreferences.hasSeenOnboarding().then((value) {
        hasSeenOnboarding = value;
      }),
      getIt<AuthUseCase>().getCurrentUser().then((value) {
        currentUser = value;
      }),
      Future<void>.delayed(_minimumSplashDuration),
    ]);

    if (!mounted) return;

    final Widget nextScreen =
        !hasSeenOnboarding
            ? const OnboardingScreen()
            : currentUser == null
            ? const LoginScreen()
            : const InboxScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionDuration: const Duration(milliseconds: 520),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.ink, AppPalette.pine, AppPalette.teal],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 154,
                height: 154,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppPalette.mist,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.lavender.withValues(alpha: 0.24),
                      blurRadius: 44,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logos/simple-logo-no-bg.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  color: AppPalette.lavender,
                  backgroundColor: AppPalette.mist.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
