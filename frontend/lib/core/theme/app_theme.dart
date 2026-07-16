import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.teal,
      brightness: Brightness.light,
      primary: AppPalette.teal,
      secondary: AppPalette.lavender,
      surface: AppPalette.mist,
      onSurface: AppPalette.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.mist,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppPalette.ink,
          fontWeight: FontWeight.w800,
          height: 0.98,
        ),
        headlineMedium: TextStyle(
          color: AppPalette.ink,
          fontWeight: FontWeight.w800,
          height: 1.04,
        ),
        bodyLarge: TextStyle(
          color: AppPalette.pine,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        bodyMedium: TextStyle(color: AppPalette.pine, height: 1.4),
      ),
    );
  }
}
