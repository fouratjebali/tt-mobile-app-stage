import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/core/errors/error_message.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';

enum NotificationKind { ready, urgent, needsEdit, processing, sent }

class NotificationCenterItem {
  const NotificationCenterItem({
    required this.kind,
    required this.email,
    required this.title,
    required this.subtitle,
  });

  final NotificationKind kind;
  final Email email;
  final String title;
  final String subtitle;
}

class NotificationCenterViewModel extends ChangeNotifier {
  NotificationCenterViewModel({required EmailUseCase emailUseCase})
    : _emailUseCase = emailUseCase;

  final EmailUseCase _emailUseCase;

  LoadState state = LoadState.idle;
  String? errorMessage;
  DateTime? lastUpdated;
  List<NotificationCenterItem> items = [];

  int get totalCount => items.length;
  int get urgentCount =>
      items.where((item) => item.kind == NotificationKind.urgent).length;
  int get readyCount =>
      items.where((item) => item.kind == NotificationKind.ready).length;
  int get editCount =>
      items.where((item) => item.kind == NotificationKind.needsEdit).length;

  Future<void> load() async {
    state = LoadState.loading;
    notifyListeners();

    try {
      final reviewEmails = await _emailUseCase.getReviewList();
      final allEmails = await _emailUseCase.getEmails();

      items = _buildItems(reviewEmails: reviewEmails, allEmails: allEmails);
      lastUpdated = DateTime.now();
      state = LoadState.success;
      errorMessage = null;
    } catch (error) {
      state = LoadState.error;
      errorMessage = ErrorMessage.fromException(error);
    }

    notifyListeners();
  }

  Future<void> refresh() => load();

  List<NotificationCenterItem> _buildItems({
    required List<Email> reviewEmails,
    required List<Email> allEmails,
  }) {
    final items = <NotificationCenterItem>[];
    final seen = <String>{};

    final sortedReview = List<Email>.from(reviewEmails)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final email in sortedReview) {
      seen.add(email.id);
      if (_isUrgent(email)) {
        items.add(
          NotificationCenterItem(
            kind: NotificationKind.urgent,
            email: email,
            title: 'Urgent email needs review',
            subtitle: _subjectOrFallback(email),
          ),
        );
        continue;
      }

      if (_isReadyToSend(email)) {
        items.add(
          NotificationCenterItem(
            kind: NotificationKind.ready,
            email: email,
            title: 'Reply ready to send',
            subtitle: _subjectOrFallback(email),
          ),
        );
        continue;
      }

      items.add(
        NotificationCenterItem(
          kind: NotificationKind.needsEdit,
          email: email,
          title: 'Draft needs a quick check',
          subtitle: _subjectOrFallback(email),
        ),
      );
    }

    final recentActivity = List<Email>.from(allEmails)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final email in recentActivity) {
      if (items.length >= 20) break;
      if (seen.contains(email.id)) continue;

      if (email.status == Status.DONE) {
        items.add(
          NotificationCenterItem(
            kind: NotificationKind.sent,
            email: email,
            title: 'Reply sent',
            subtitle: _subjectOrFallback(email),
          ),
        );
      } else if (email.status == Status.PENDING_ANALYSIS ||
          email.status == Status.PENDING_JURY) {
        items.add(
          NotificationCenterItem(
            kind: NotificationKind.processing,
            email: email,
            title: 'Email is being prepared',
            subtitle: _subjectOrFallback(email),
          ),
        );
      }
    }

    return items;
  }

  bool _isUrgent(Email email) {
    return (email.analysis?.priority ?? Priority.NORMAL) == Priority.URGENT;
  }

  bool _isReadyToSend(Email email) {
    final hasReply = email.analysis?.suggestedReply.trim().isNotEmpty == true;
    return hasReply && email.jury?.verdict == JuryVerdict.APPROVED;
  }

  String _subjectOrFallback(Email email) {
    final subject = email.subject.trim();
    return subject.isEmpty ? '(No subject)' : subject;
  }
}
