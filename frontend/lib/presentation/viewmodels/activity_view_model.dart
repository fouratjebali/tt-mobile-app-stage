import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';

enum ActivityFilter { all, autoSent, review, low }

class ActivityViewModel extends ChangeNotifier {
  ActivityViewModel({required EmailUseCase emailUseCase})
      : _emailUseCase = emailUseCase;

  final EmailUseCase _emailUseCase;

  LoadState state = LoadState.idle;
  String? errorMessage;
  List<Email> allEmails = [];
  DateTime selectedDate = DateTime.now();
  ActivityFilter filter = ActivityFilter.all;

  List<Email> get filteredEmails {
    switch (filter) {
      case ActivityFilter.all:
        return allEmails;
      case ActivityFilter.autoSent:
        return allEmails.where((e) => e.status == Status.DONE).toList();
      case ActivityFilter.review:
        return allEmails
            .where((e) => e.status == Status.PENDING_USER_REVIEW)
            .toList();
      case ActivityFilter.low:
        return allEmails
            .where((e) => e.analysis?.priority == Priority.LOW)
            .toList();
    }
  }

  Future<void> loadTodayEmails() async {
    state = LoadState.loading;
    notifyListeners();

    try {
      final all = await _emailUseCase.getEmails();
      allEmails = all.where((e) => _isSameDay(e.date, selectedDate)).toList();
      state = LoadState.success;
      errorMessage = null;
    } catch (_) {
      state = LoadState.error;
      errorMessage = 'Unable to load activity. Pull down to retry.';
    }
    notifyListeners();
  }

  void applyFilter(ActivityFilter newFilter) {
    filter = newFilter;
    notifyListeners();
  }

  Future<void> loadPreviousDay() async {
    selectedDate = selectedDate.subtract(const Duration(days: 1));
    await loadTodayEmails();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate = date;
    await loadTodayEmails();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}