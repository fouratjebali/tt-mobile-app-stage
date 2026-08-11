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

    
  // NOTE : getDarkMode/setDarkMode ne sont pas exposées ici — l'écran
  // Profile utilise directement ThemeController pour le dark mode, car
  // c'est lui qui contrôle réellement l'apparence de l'app et persiste
  // déjà sur la même clé SharedPreferences ('darkMode'). Pas besoin de
  // dupliquer l'appel.
}