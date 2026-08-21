import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_language_controller.dart';
import 'package:tt_mail_assistant/core/theme/app_theme.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/splash_screen.dart';

class TTMailApp extends StatelessWidget {
  const TTMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = getIt<ThemeController>();
    final languageController = getIt<AppLanguageController>();

    return AnimatedBuilder(
      animation: Listenable.merge([themeController, languageController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'TT Mail Assistant',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          locale: Locale(languageController.language.code),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}
