import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/theme/app_theme.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/splash_screen.dart';

class TTMailApp extends StatelessWidget {
  const TTMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TT Mail Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
