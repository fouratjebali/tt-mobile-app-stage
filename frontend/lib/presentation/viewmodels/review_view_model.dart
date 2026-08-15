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
  String? actionErrorMessage;
  bool isSubmittingAction = false;
  List<Email> emails = [];
  Future<void> Function()? _lastFailedAction;
  final Set<String> _handledEmailIds = <String>{};

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
      final loaded = await _emailUseCase.getReviewList();
      emails = loaded
          .where((email) => !_handledEmailIds.contains(email.id))
          .toList(growable: false);
      state = LoadState.success;
      errorMessage = null;
    } catch (_) {
      state = LoadState.error;
      errorMessage = 'Unable to load review emails. Pull down to retry.';
    }
    notifyListeners();
  }

  Future<void> refresh() => loadReviewEmails();

  Future<void> validateAndSend(String emailId) async {
    final body = _resolveReplyBody(emailId);
    await _runActionWithRetry(
      actionLabel: 'send this reply',
      completedEmailId: emailId,
      action: () => _emailUseCase.validateAndSend(emailId: emailId, body: body),
    );
  }

  Future<void> editAndSend(String emailId, String editedBody) async {
    final body = editedBody.trim();
    if (body.isEmpty) {
      actionErrorMessage = 'Reply cannot be empty.';
      notifyListeners();
      return;
    }
    await _runActionWithRetry(
      actionLabel: 'send edited reply',
      completedEmailId: emailId,
      action: () => _emailUseCase.editAndSend(emailId: emailId, body: body),
    );
  }

  Future<void> reject(String emailId) async {
    await _runActionWithRetry(
      actionLabel: 'reject this email',
      completedEmailId: emailId,
      action: () => _emailUseCase.reject(emailId: emailId),
    );
  }

  Future<void> retryLastAction() async {
    final retry = _lastFailedAction;
    if (retry == null || isSubmittingAction) return;
    await retry();
  }

  Future<void> _runActionWithRetry({
    required String actionLabel,
    required String completedEmailId,
    required Future<void> Function() action,
  }) async {
    actionErrorMessage = null;
    isSubmittingAction = true;
    notifyListeners();
    try {
      await action();
      _lastFailedAction = null;
      _handledEmailIds.add(completedEmailId);
      emails = emails.where((email) => email.id != completedEmailId).toList();
      await loadReviewEmails();
    } catch (error) {
      _lastFailedAction =
          () => _runActionWithRetry(
            actionLabel: actionLabel,
            completedEmailId: completedEmailId,
            action: action,
          );
      actionErrorMessage = 'Unable to $actionLabel. ${_toUserMessage(error)}';
    } finally {
      isSubmittingAction = false;
      notifyListeners();
    }
  }

  String _resolveReplyBody(String emailId) {
    Email? target;
    for (final email in emails) {
      if (email.id == emailId) {
        target = email;
        break;
      }
    }
    if (target == null) {
      return 'Hi,\n\nThanks for your message. We will get back to you shortly.\n\nBest regards,';
    }
    final suggested = target.analysis?.suggestedReply.trim() ?? '';
    if (suggested.isNotEmpty) return suggested;

    final plainBody = target.body.plain.trim();
    if (plainBody.isNotEmpty) return plainBody;

    return 'Hi,\n\nThanks for your message. We will get back to you shortly.\n\nBest regards,';
  }

  String _toUserMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Please retry.';
    }
    if (raw.length > 200) {
      return '${raw.substring(0, 200)}...';
    }
    return raw;
  }
}
