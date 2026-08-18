import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/settings_usecase.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required EmailUseCase emailUseCase,
    required SettingsUseCase settingsUseCase,
    required AuthUseCase authUseCase,
  }) : _emailUseCase = emailUseCase,
       _settingsUseCase = settingsUseCase,
       _authUseCase = authUseCase;

  final EmailUseCase _emailUseCase;
  final SettingsUseCase _settingsUseCase;
  final AuthUseCase _authUseCase;

  LoadState state = LoadState.idle;
  String? errorMessage;

  String userName = 'User';
  String? userEmail;
  String? userPhotoUrl;
  bool agentActive = true;
  int processedToday = 0;
  int autoSent = 0;
  int needReview = 0;
  double accuracyRate = 0;
  List<Email> recentEmails = [];

  Future<void> loadSummary() async {
    state = LoadState.loading;
    notifyListeners();

    try {
      final user = await _authUseCase.getCurrentUser();
      final emails = await _emailUseCase.getEmails();
      final stats = await _emailUseCase.getDashboardStats(period: '7d');
      final autoProcessing = await _settingsUseCase.getAutoProcessing();

      final processed = _asInt(stats['processed_count']);
      final sent = _asInt(stats['sent_count']);
      final review = _asInt(stats['review_count']);
      final accuracy = processed == 0 ? 0.0 : (sent / processed) * 100;

      userName =
          (user?.displayName?.trim().isNotEmpty ?? false)
              ? user!.displayName!.trim().split(' ').first
              : 'User';
      userEmail = user?.email;
      userPhotoUrl = _cleanPhotoUrl(user?.photoUrl);
      agentActive = autoProcessing;
      processedToday = processed;
      autoSent = sent;
      needReview = review;
      accuracyRate = accuracy;
      recentEmails = emails.take(3).toList(growable: false);

      state = LoadState.success;
      errorMessage = null;
    } catch (_) {
      state = LoadState.error;
      errorMessage = 'Activity could not be refreshed. Pull down to retry.';
    }
    notifyListeners();
  }

  Future<void> refresh() => loadSummary();

  Future<void> toggleAgent(bool value) async {
    agentActive = value;
    notifyListeners();
    await _settingsUseCase.setAutoProcessing(value);
  }

  String? _cleanPhotoUrl(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
