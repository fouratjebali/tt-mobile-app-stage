import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel({required EmailUseCase emailUseCase})
      : _emailUseCase = emailUseCase;

  final EmailUseCase _emailUseCase;

  LoadState state = LoadState.idle;
  String? errorMessage;
  List<Email> emails = [];

  int get pendingCount => emails.length;

  /// Emails sorted: URGENT first, then NORMAL, then LOW.
  List<Email> get sortedEmails {
    final sorted = List<Email>.from(emails);
    sorted.sort((a, b) {
      final pa = a.analysis?.priority ?? Priority.NORMAL;
      final pb = b.analysis?.priority ?? Priority.NORMAL;
      return _priorityOrder(pa).compareTo(_priorityOrder(pb));
    });
    return sorted;
  }

  int _priorityOrder(Priority p) {
    switch (p) {
      case Priority.URGENT:
        return 0;
      case Priority.NORMAL:
        return 1;
      case Priority.LOW:
        return 2;
    }
  }

  Future<void> loadReviewEmails() async {
    state = LoadState.loading;
    notifyListeners();
    try {
      emails = await _emailUseCase.getReviewList();
      state = LoadState.success;
      errorMessage = null;
    } catch (_) {
      state = LoadState.error;
      errorMessage = 'Unable to load review emails. Pull down to retry.';
    }
    notifyListeners();
  }

  Future<void> refresh() => loadReviewEmails();

  Future<void> sendReply(String emailId, String body) async {
    await _emailUseCase.sendReply(emailId: emailId, body: body);
    await loadReviewEmails();
  }
}
