import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPreferences prefs;

  SettingsRepositoryImpl(this.prefs);

  @override
  Future<bool> getAutoProcessing() async {
    return prefs.getBool('autoProcessing') ?? true;
  }

  @override
  Future<void> setAutoProcessing(bool value) async {
    await prefs.setBool('autoProcessing', value);
  }

  @override
  Future<bool> getNotifications() async {
    return prefs.getBool('notifications') ?? true;
  }

  @override
  Future<void> setNotifications(bool value) async {
    await prefs.setBool('notifications', value);
  }

  @override
  Future<bool> getDarkMode() async {
    return prefs.getBool('darkMode') ?? true;
  }

  @override
  Future<void> setDarkMode(bool value) async {
    await prefs.setBool('darkMode', value);
  }

  @override
  Future<bool> getDailySummary() async {
    return prefs.getBool('dailySummary') ?? true;
  }

  @override
  Future<void> setDailySummary(bool value) async {
    await prefs.setBool('dailySummary', value);
  }

  @override
  Future<double> getConfidenceThreshold() async {
    return prefs.getDouble('confidenceThreshold') ?? 80.0;
  }

  @override
  Future<void> setConfidenceThreshold(double value) async {
    await prefs.setDouble('confidenceThreshold', value);
  }

  @override
  Future<double> getUrgencyThreshold() async {
    return prefs.getDouble('urgencyThreshold') ?? 7.0;
  }

  @override
  Future<void> setUrgencyThreshold(double value) async {
    await prefs.setDouble('urgencyThreshold', value);
  }
}