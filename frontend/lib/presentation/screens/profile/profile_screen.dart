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
      final currentUser = await _authRepository.getCurrentUser();

      if (mounted) {
        setState(() {
          autoProcessing = autoProc;
          notifications = notif;
          darkMode = darkM;
          dailySummary = dailySumm;
          confidenceThreshold = confThresh;
          urgencyThreshold = urgThresh;

          // Set user info
          if (currentUser != null) {
            userName = currentUser.displayName ?? 'User';
            userEmail = currentUser.email;
            userPhotoUrl = currentUser.photoUrl;
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

  Future<void> _signOut() async {
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
          _ThresholdCard(
            title: 'Urgency Threshold',
            subtitle: 'Score: ${urgencyThreshold.toStringAsFixed(1)}',
            value: urgencyThreshold,
            onChanged: (val) => _updateUrgencyThreshold(val as double),
            isSwitch: false,
            min: 1,
            max: 10,
          ),
          const SizedBox(height: 12),
          _ThresholdCard(
            title: 'Jury Confidence Min',
            subtitle: 'Score: ${confidenceThreshold.toStringAsFixed(0)}%',
            value: confidenceThreshold,
            onChanged: (val) => _updateConfidenceThreshold(val as double),
            isSwitch: false,
            min: 0,
            max: 100,
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
          GestureDetector(
            onTap: () {},
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
                        'French',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
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
              child: userPhotoUrl == null
                  ? const Icon(Icons.person, size: 32)
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isSwitch,
    this.min = 0,
    this.max = 100,
  });

  final String title;
  final String subtitle;
  final dynamic value;
  final Function(dynamic) onChanged;
  final bool isSwitch;
  final double min;
  final double max;

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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
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
              )
            else
              SizedBox(
                width: 100,
                child: Slider(
                  value: value as double,
                  onChanged: (newValue) async {
                    await onChanged(newValue);
                  },
                  min: min,
                  max: max,
                  divisions: max > 10 ? 10 : null,
                  activeColor: AppPalette.lavender,
                ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
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
