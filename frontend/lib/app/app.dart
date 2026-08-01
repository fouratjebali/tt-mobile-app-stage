import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_theme.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/splash_screen.dart';

class TTMailApp extends StatelessWidget {
  const TTMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = getIt<ThemeController>();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'TT Mail Assistant',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
