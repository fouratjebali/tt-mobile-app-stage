abstract class SettingsRepository {
  Future<bool> getAutoProcessing();

  Future<void> setAutoProcessing(bool value);

  Future<bool> getNotifications();

  Future<void> setNotifications(bool value);

  Future<bool> getDarkMode();

  Future<void> setDarkMode(bool value);

  Future<bool> getDailySummary();

  Future<void> setDailySummary(bool value);

  Future<double> getConfidenceThreshold();

  Future<void> setConfidenceThreshold(double value);

  Future<double> getUrgencyThreshold();

  Future<void> setUrgencyThreshold(double value);

  Future<String> getReplyLanguage();

  Future<void> setReplyLanguage(String value);

  Future<String> getAppLanguage();

  Future<void> setAppLanguage(String value);
}
