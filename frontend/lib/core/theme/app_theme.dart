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
      surface: const Color(0xFF101614),
      onSurface: AppPalette.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF101614),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF101614),
        foregroundColor: AppPalette.white,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          color: AppPalette.white,
          fontWeight: FontWeight.w800,
          height: 0.98,
        ),
        headlineMedium: const TextStyle(
          color: AppPalette.white,
          fontWeight: FontWeight.w800,
          height: 1.04,
        ),
        bodyLarge: TextStyle(
          color: AppPalette.white.withValues(alpha: 0.84),
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: AppPalette.white.withValues(alpha: 0.74),
          height: 1.4,
        ),
        labelLarge: const TextStyle(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF151C1A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppPalette.white.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.teal,
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
                  : AppPalette.white.withValues(alpha: 0.72),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppPalette.teal
                  : AppPalette.white.withValues(alpha: 0.16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF151C1A),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
