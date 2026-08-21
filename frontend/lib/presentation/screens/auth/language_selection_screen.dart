import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_language_controller.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/services/launch_preferences.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/login_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage _selected = getIt<AppLanguageController>().language;

  Future<void> _continue() async {
    await getIt<AppLanguageController>().setLanguage(_selected);
    await getIt<SettingsRepository>().setReplyLanguage(_selected.replyLanguage);
    if (!mounted) return;

    final hasSeenOnboarding = await LaunchPreferences.hasSeenOnboarding();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                hasSeenOnboarding
                    ? const LoginScreen()
                    : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.mist, AppPalette.white, Color(0xFFDDE2D7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset('assets/logos/simple-logo-no-bg.png'),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'TT Mail Assistant',
                      style: TextStyle(
                        color: AppPalette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  l10n.t('language.title'),
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.t('language.subtitle'),
                  style: const TextStyle(
                    color: AppPalette.pine,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 28),
                _LanguageChoice(
                  label: l10n.t('language.english'),
                  subtitle: 'Use the app in English',
                  selected: _selected == AppLanguage.english,
                  onTap: () => setState(() => _selected = AppLanguage.english),
                ),
                const SizedBox(height: 12),
                _LanguageChoice(
                  label: l10n.t('language.french'),
                  subtitle: 'Utiliser l’application en français',
                  selected: _selected == AppLanguage.french,
                  onTap: () => setState(() => _selected = AppLanguage.french),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.teal,
                      foregroundColor: AppPalette.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      l10n.t('language.continue'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppPalette.sage : AppPalette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppPalette.teal : AppPalette.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppPalette.pine.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppPalette.teal : AppPalette.pine,
            ),
          ],
        ),
      ),
    );
  }
}
