import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
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
  double confidenceThreshold = 80.0;
  double urgencyThreshold = 7.0;
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
      final confThresh = await _settingsRepository.getConfidenceThreshold();
      final urgThresh = await _settingsRepository.getUrgencyThreshold();
      final language = await _settingsRepository.getReplyLanguage();
      final currentUser = await _authRepository.getCurrentUser();

      if (mounted) {
        setState(() {
          autoProcessing = autoProc;
          notifications = notif;
          darkMode = darkM;
          dailySummary = dailySumm;
          confidenceThreshold = confThresh;
          urgencyThreshold = urgThresh;
          replyLanguage = _normalizedLanguage(language);

          // Set user info
          if (currentUser != null) {
            userName = currentUser.displayName ?? 'User';
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

  Future<void> _updateConfidenceThreshold(double value) async {
    setState(() {
      confidenceThreshold = value;
    });
    await _settingsRepository.setConfidenceThreshold(value);
  }

  Future<void> _updateUrgencyThreshold(double value) async {
    setState(() {
      urgencyThreshold = value;
    });
    await _settingsRepository.setUrgencyThreshold(value);
  }

  Future<void> _updateReplyLanguage(String value) async {
    final language = _normalizedLanguage(value);
    setState(() {
      replyLanguage = language;
    });
    await _settingsRepository.setReplyLanguage(language);
  }

  String _normalizedLanguage(String value) {
    return value.toLowerCase() == 'french' ? 'French' : 'English';
  }

  String? _cleanPhotoUrl(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _showReplyLanguagePicker() async {
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
                const Text(
                  'Reply language',
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to connect your Gmail account again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out'),
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
        appBar: AppBar(title: const Text('Profile & Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ACCOUNT SECTION
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 12),
          _AccountCard(
            userName: userName ?? 'User',
            userEmail: userEmail ?? 'user@email.com',
            userPhotoUrl: userPhotoUrl,
          ),
          const SizedBox(height: 32),

          // AGENT SETTINGS SECTION
          _SectionHeader(title: 'Agent Settings'),
          const SizedBox(height: 12),
          _ThresholdCard(
            title: 'Auto-processing',
            subtitle: 'Agent automatically processes emails',
            value: autoProcessing,
            onChanged: (val) => _updateAutoProcessing(val as bool),
            isSwitch: true,
          ),
          const SizedBox(height: 12),
          _SliderSettingCard(
            title: 'Urgency Threshold',
            subtitle: 'Score: ${urgencyThreshold.toStringAsFixed(1)}',
            value: urgencyThreshold,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: _updateUrgencyThreshold,
          ),
          const SizedBox(height: 12),
          _SliderSettingCard(
            title: 'Jury Confidence Min',
            subtitle: 'Score: ${confidenceThreshold.toStringAsFixed(0)}%',
            value: confidenceThreshold,
            min: 0,
            max: 100,
            divisions: 10,
            onChanged: _updateConfidenceThreshold,
          ),
          const SizedBox(height: 32),

          // APP PREFERENCES SECTION
          _SectionHeader(title: 'App Preferences'),
          const SizedBox(height: 12),
          _PreferenceToggle(
            title: 'Push notifications',
            value: notifications,
            onChanged: _updateNotifications,
          ),
          const SizedBox(height: 12),
          _PreferenceToggle(
            title: 'Daily summary',
            value: dailySummary,
            onChanged: _updateDailySummary,
          ),
          const SizedBox(height: 12),
          _PreferenceToggle(
            title: 'Dark mode',
            value: darkMode,
            onChanged: _updateDarkMode,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showReplyLanguagePicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reply language',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        replyLanguage,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // LOGOUT BUTTON
          ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppPalette.lavender.withValues(alpha: 0.2),
              backgroundImage:
                  userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
              child:
                  userPhotoUrl == null
                      ? Text(
                        _initials(userName, userEmail),
                        style: const TextStyle(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Gmail connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
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

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isSwitch,
  });

  final String title;
  final String subtitle;
  final dynamic value;
  final Function(dynamic) onChanged;
  final bool isSwitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isSwitch)
              Switch(
                value: value as bool,
                onChanged: (newValue) async {
                  await onChanged(newValue);
                },
                activeColor: AppPalette.lavender,
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderSettingCard extends StatelessWidget {
  const _SliderSettingCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  subtitle.replaceFirst('Score: ', ''),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Slider(
              value: value.clamp(min, max),
              onChanged: onChanged,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: AppPalette.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Switch(
              value: value,
              onChanged: (newValue) async {
                await onChanged(newValue);
              },
              activeColor: AppPalette.lavender,
            ),
          ],
        ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected
                    ? AppPalette.teal
                    : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
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
