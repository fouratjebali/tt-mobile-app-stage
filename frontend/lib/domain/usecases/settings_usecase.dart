import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';

class SettingsUseCase {
  const SettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<bool> getAutoProcessing() => _repository.getAutoProcessing();
  Future<void> setAutoProcessing(bool value) =>
      _repository.setAutoProcessing(value);

  Future<bool> getNotifications() => _repository.getNotifications();
  Future<void> setNotifications(bool value) =>
      _repository.setNotifications(value);

  Future<double> getUrgencyThreshold() => _repository.getUrgencyThreshold();
  Future<void> setUrgencyThreshold(double value) =>
      _repository.setUrgencyThreshold(value);

  Future<double> getConfidenceThreshold() =>
      _repository.getConfidenceThreshold();
  Future<void> setConfidenceThreshold(double value) =>
      _repository.setConfidenceThreshold(value);

  Future<String> getReplyLanguage() => _repository.getReplyLanguage();
  Future<void> setReplyLanguage(String value) =>
      _repository.setReplyLanguage(value);

  Future<String> getAppLanguage() => _repository.getAppLanguage();
  Future<void> setAppLanguage(String value) =>
      _repository.setAppLanguage(value);
}
