import 'package:shared_preferences/shared_preferences.dart';

class LaunchPreferences {
  const LaunchPreferences._();

  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  static Future<bool> hasSeenOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_hasSeenOnboardingKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hasSeenOnboardingKey, true);
  }
}
