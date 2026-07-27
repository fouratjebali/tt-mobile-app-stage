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
  Future<double> getThreshold() async {
    return prefs.getDouble('threshold') ?? 80;
  }

  @override
  Future<void> setThreshold(double value) async {
    await prefs.setDouble('threshold', value);
  }
}