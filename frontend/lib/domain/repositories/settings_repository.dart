abstract class SettingsRepository {
  Future<bool> getAutoProcessing();

  Future<void> setAutoProcessing(bool value);

  Future<bool> getNotifications();

  Future<void> setNotifications(bool value);

  Future<bool> getDarkMode();

  Future<void> setDarkMode(bool value);

  Future<double> getThreshold();

  Future<void> setThreshold(double value);
}