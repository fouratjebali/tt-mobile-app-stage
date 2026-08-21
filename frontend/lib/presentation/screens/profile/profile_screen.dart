import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_language_controller.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/core/utils/avatar_image_provider.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SettingsRepository _settingsRepository;
  late AuthRepository _authRepository;

  // State variables
  String? userName;
  String? userEmail;
  String? userPhotoUrl;

  bool autoProcessing = true;
  bool notifications = true;
  bool darkMode = false;
  bool dailySummary = true;
  AppLanguage appLanguage = AppLanguage.english;
  String replyLanguage = 'English';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _settingsRepository = getIt<SettingsRepository>();
    _authRepository = getIt<AuthRepository>();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      // Load all preferences from SettingsRepository
      final autoProc = await _settingsRepository.getAutoProcessing();
      final notif = await _settingsRepository.getNotifications();
      final darkM = await _settingsRepository.getDarkMode();
      final dailySumm = await _settingsRepository.getDailySummary();
      final appLang = getIt<AppLanguageController>().language;
      final language = await _settingsRepository.getReplyLanguage();
      final currentUser = await _authRepository.getCurrentUser();

      if (mounted) {
        setState(() {
          autoProcessing = autoProc;
          notifications = notif;
          darkMode = darkM;
          dailySummary = dailySumm;
          appLanguage = appLang;
          replyLanguage = _normalizedLanguage(language);

          // Set user info
          if (currentUser != null) {
            userName =
                currentUser.displayName ?? context.l10n.t('settings.user');
            userEmail = currentUser.email;
            userPhotoUrl = _cleanPhotoUrl(currentUser.photoUrl);
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateAutoProcessing(bool value) async {
    setState(() {
      autoProcessing = value;
    });
    await _settingsRepository.setAutoProcessing(value);
  }

  Future<void> _updateNotifications(bool value) async {
    setState(() {
      notifications = value;
    });
    await _settingsRepository.setNotifications(value);
  }

  Future<void> _updateDarkMode(bool value) async {
    setState(() {
      darkMode = value;
    });
    await _settingsRepository.setDarkMode(value);
    await getIt<ThemeController>().setDarkMode(value);
  }

  Future<void> _updateDailySummary(bool value) async {
    setState(() {
      dailySummary = value;
    });
    await _settingsRepository.setDailySummary(value);
  }

  Future<void> _updateReplyLanguage(String value) async {
    final language = _normalizedLanguage(value);
    setState(() {
      replyLanguage = language;
    });
    await _settingsRepository.setReplyLanguage(language);
  }

  Future<void> _updateAppLanguage(AppLanguage language) async {
    setState(() {
      appLanguage = language;
      replyLanguage = language.replyLanguage;
    });
    await getIt<AppLanguageController>().setLanguage(language);
    await _settingsRepository.setAppLanguage(language.code);
    await _settingsRepository.setReplyLanguage(language.replyLanguage);
  }

  String _normalizedLanguage(String value) {
    return value.toLowerCase() == 'french' ? 'French' : 'English';
  }

  String? _cleanPhotoUrl(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _showReplyLanguagePicker() async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('settings.replyLanguage'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  label: 'English',
                  selected: replyLanguage == 'English',
                  onTap: () => Navigator.pop(context, 'English'),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: 'French',
                  selected: replyLanguage == 'French',
                  onTap: () => Navigator.pop(context, 'French'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _updateReplyLanguage(selected);
    }
  }

  Future<void> _showAppLanguagePicker() async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('settings.appLanguage'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  label: l10n.t('language.english'),
                  selected: appLanguage == AppLanguage.english,
                  onTap: () => Navigator.pop(context, AppLanguage.english),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: l10n.t('language.french'),
                  selected: appLanguage == AppLanguage.french,
                  onTap: () => Navigator.pop(context, AppLanguage.french),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _updateAppLanguage(selected);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.t('settings.signOutTitle')),
          content: Text(l10n.t('settings.signOutMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('settings.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.t('settings.signOutAction')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _authRepository.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tone = _ProfileTone.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              l10n.t('settings.title'),
              style: TextStyle(
                color: tone.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('settings.subtitle'),
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _AccountCard(
              userName: userName ?? l10n.t('settings.user'),
              userEmail: userEmail ?? 'user@email.com',
              userPhotoUrl: userPhotoUrl,
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.t('settings.emailHandling')),
            const SizedBox(height: 10),
            _AssistantControlPanel(
              isActive: autoProcessing,
              title: l10n.t('settings.prepareReplies'),
              activeSubtitle: l10n.t('settings.prepareRepliesOn'),
              inactiveSubtitle: l10n.t('settings.prepareRepliesOff'),
              onChanged: _updateAutoProcessing,
            ),
            const SizedBox(height: 12),
            _LanguageTile(
              title: l10n.t('settings.appLanguage'),
              subtitle: l10n.languageName(appLanguage),
              color: AppPalette.teal,
              onTap: _showAppLanguagePicker,
            ),
            const SizedBox(height: 12),
            _LanguageTile(
              title: l10n.t('settings.replyLanguage'),
              language: replyLanguage,
              subtitle: l10n.t('settings.replyLanguageSubtitle'),
              color: AppPalette.blue,
              onTap: _showReplyLanguagePicker,
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.t('settings.preferences')),
            const SizedBox(height: 10),
            _PreferenceToggle(
              icon: Icons.notifications_none_rounded,
              title: l10n.t('settings.notifications'),
              subtitle: l10n.t('settings.notificationsSubtitle'),
              value: notifications,
              onChanged: _updateNotifications,
            ),
            const SizedBox(height: 10),
            _PreferenceToggle(
              icon: Icons.summarize_outlined,
              title: l10n.t('settings.dailySummary'),
              subtitle: l10n.t('settings.dailySummarySubtitle'),
              value: dailySummary,
              onChanged: _updateDailySummary,
            ),
            const SizedBox(height: 10),
            _PreferenceToggle(
              icon: Icons.dark_mode_outlined,
              title: l10n.t('settings.darkMode'),
              subtitle: l10n.t('settings.darkModeSubtitle'),
              value: darkMode,
              onChanged: _updateDarkMode,
            ),
            const SizedBox(height: 28),
            _SignOutButton(
              label: l10n.t('settings.signOut'),
              onPressed: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTone {
  const _ProfileTone({
    required this.surface,
    required this.softSurface,
    required this.border,
    required this.text,
    required this.muted,
  });

  final Color surface;
  final Color softSurface;
  final Color border;
  final Color text;
  final Color muted;

  static _ProfileTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ProfileTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
      softSurface:
          isDark ? AppPalette.white.withValues(alpha: 0.07) : AppPalette.sage,
      border:
          isDark ? AppPalette.white.withValues(alpha: 0.08) : AppPalette.line,
      text: isDark ? AppPalette.white : AppPalette.ink,
      muted:
          isDark
              ? AppPalette.white.withValues(alpha: 0.62)
              : AppPalette.pine.withValues(alpha: 0.68),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);

    return Text(
      title,
      style: TextStyle(
        color: tone.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
  });

  final String userName;
  final String userEmail;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);
    final l10n = context.l10n;
    final avatarImage = avatarImageProvider(userPhotoUrl);

    return _SettingCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: tone.softSurface,
              backgroundImage: avatarImage,
              child:
                  avatarImage == null
                      ? Text(
                        _initials(userName, userEmail),
                        style: TextStyle(
                          color: tone.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: tone.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(fontSize: 14, color: tone.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.t('settings.outlookConnected'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.deepTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _AssistantControlPanel extends StatelessWidget {
  const _AssistantControlPanel({
    required this.isActive,
    required this.title,
    required this.activeSubtitle,
    required this.inactiveSubtitle,
    required this.onChanged,
  });

  final bool isActive;
  final String title;
  final String activeSubtitle;
  final String inactiveSubtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppPalette.deepTeal : AppPalette.amber;
    final tone = _ProfileTone.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive
                  ? Icons.mark_email_read_outlined
                  : Icons.pause_circle_outline,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? activeSubtitle : inactiveSubtitle,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: isActive, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.language,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String? language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);

    return _SettingCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.language_rounded, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      language == null ? subtitle : '$language - $subtitle',
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tone.muted, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: child,
    );
  }
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);
    final color = value ? AppPalette.deepTeal : tone.muted;

    return _SettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tone.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: tone.muted,
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: (newValue) async {
                await onChanged(newValue);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded, size: 19),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.clay,
        side: BorderSide(color: AppPalette.clay.withValues(alpha: 0.38)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _ProfileTone.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppPalette.teal : tone.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppPalette.teal, size: 20),
          ],
        ),
      ),
    );
  }
}
