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
      fontFamily: 'Inter',
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
        labelLarge: TextStyle(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppPalette.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppPalette.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.deepTeal,
          foregroundColor: AppPalette.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppPalette.white
                  : AppPalette.pine,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppPalette.deepTeal
                  : AppPalette.line,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.teal,
      brightness: Brightness.dark,
      primary: AppPalette.teal,
      secondary: AppPalette.lavender,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      fontFamily: 'Inter',
    );
  }
}
