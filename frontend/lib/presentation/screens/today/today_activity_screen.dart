import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/activity_view_model.dart';

class TodayActivityScreen extends StatefulWidget {
  const TodayActivityScreen({super.key});

  @override
  State<TodayActivityScreen> createState() => _TodayActivityScreenState();
}

class _TodayActivityScreenState extends State<TodayActivityScreen> {
  late final ActivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<ActivityViewModel>();
    _viewModel.addListener(_onChanged);
    _viewModel.loadTodayEmails();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final tone = _TodayTone.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppPalette.deepTeal,
              surface: tone.surface,
              onSurface: tone.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _viewModel.selectedDate) {
      await _viewModel.selectDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emails = _viewModel.filteredEmails;
    final isLoading =
        _viewModel.state == LoadState.loading ||
        _viewModel.state == LoadState.idle;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodayHeader(
              selectedDate: _viewModel.selectedDate,
              reviewCount: _countStatus(Status.PENDING_USER_REVIEW),
              onPickDate: () => _selectDate(context),
              onPreviousDay: _viewModel.loadPreviousDay,
              onToday: () => _viewModel.selectDate(DateTime.now()),
            ),
            _FilterRail(
              selected: _viewModel.filter,
              allCount: _viewModel.allEmails.length,
              sentCount: _countStatus(Status.DONE),
              reviewCount: _countStatus(Status.PENDING_USER_REVIEW),
              lowCount: _countLowPriority(),
              onChanged: _viewModel.applyFilter,
            ),
            if (_viewModel.state == LoadState.error)
              _Notice(message: _viewModel.errorMessage ?? ''),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : emails.isEmpty
                      ? _EmptyState(filter: _viewModel.filter)
                      : RefreshIndicator(
                        onRefresh: _viewModel.loadTodayEmails,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: emails.length,
                          itemBuilder: (context, index) {
                            final email = emails[index];
                            return _TimelineEmailItem(
                              email: email,
                              isFirst: index == 0,
                              isLast: index == emails.length - 1,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => EmailDetailScreen(email: email),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  int _countStatus(Status status) {
    return _viewModel.allEmails.where((email) => email.status == status).length;
  }

  int _countLowPriority() {
    return _viewModel.allEmails
        .where((email) => email.analysis?.priority == Priority.LOW)
        .length;
  }
}

class _TodayTone {
  const _TodayTone({
    required this.surface,
    required this.softSurface,
    required this.border,
    required this.text,
    required this.muted,
  });

  final Color surface;
  final Color softSurface;
  final Color border;
  final Color text;
  final Color muted;

  static _TodayTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _TodayTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
      softSurface:
          isDark
              ? AppPalette.white.withValues(alpha: 0.07)
              : AppPalette.sage.withValues(alpha: 0.62),
      border:
          isDark ? AppPalette.white.withValues(alpha: 0.08) : AppPalette.line,
      text: isDark ? AppPalette.white : AppPalette.ink,
      muted:
          isDark
              ? AppPalette.white.withValues(alpha: 0.62)
              : AppPalette.pine.withValues(alpha: 0.68),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.selectedDate,
    required this.reviewCount,
    required this.onPickDate,
    required this.onPreviousDay,
    required this.onToday,
  });

  final DateTime selectedDate;
  final int reviewCount;
  final VoidCallback onPickDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('today.title'),
            style: TextStyle(
              color: tone.text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('today.subtitle'),
            style: TextStyle(
              color: tone.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: _formatDate(context, selectedDate),
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(
                tooltip: l10n.t('today.previousDay'),
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousDay,
              ),
              const SizedBox(width: 8),
              _IconAction(
                tooltip: l10n.t('today.title'),
                icon: Icons.today_rounded,
                onTap: onToday,
              ),
            ],
          ),
          if (reviewCount > 0) ...[
            const SizedBox(height: 10),
            _HeaderNotice(
              label: '$reviewCount ${l10n.t('today.waitingReview')}',
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderNotice extends StatelessWidget {
  const _HeaderNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.clay.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.rate_review_outlined,
            color: AppPalette.clay,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.clay,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppPalette.lavender
                        : AppPalette.deepTeal,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: tone.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.border),
            ),
            child: Icon(icon, color: tone.text, size: 21),
          ),
        ),
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.selected,
    required this.allCount,
    required this.sentCount,
    required this.reviewCount,
    required this.lowCount,
    required this.onChanged,
  });

  final ActivityFilter selected;
  final int allCount;
  final int sentCount;
  final int reviewCount;
  final int lowCount;
  final ValueChanged<ActivityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = [
      _FilterOption(ActivityFilter.all, l10n.t('filter.all'), allCount),
      _FilterOption(ActivityFilter.autoSent, l10n.t('filter.sent'), sentCount),
      _FilterOption(
        ActivityFilter.review,
        l10n.t('filter.review'),
        reviewCount,
      ),
      _FilterOption(ActivityFilter.low, l10n.t('filter.low'), lowCount),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return _FilterChipButton(
            label: '${filter.label} ${filter.count}',
            selected: selected == filter.filter,
            onTap: () => onChanged(filter.filter),
          );
        },
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.filter, this.label, this.count);

  final ActivityFilter filter;
  final String label;
  final int count;
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);
    final active =
        Theme.of(context).brightness == Brightness.dark
            ? AppPalette.lavender
            : AppPalette.deepTeal;

    return Material(
      color: selected ? active.withValues(alpha: 0.14) : tone.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? active.withValues(alpha: 0.34) : tone.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? active : tone.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineEmailItem extends StatelessWidget {
  const _TimelineEmailItem({
    required this.email,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final Email email;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);
    final statusColor = _statusColor(email.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : tone.border,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    _statusIcon(email.status),
                    color: statusColor,
                    size: 17,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : tone.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimelineCard(
                email: email,
                statusColor: statusColor,
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.email,
    required this.statusColor,
    required this.onTap,
  });

  final Email email;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);
    final priority = email.analysis?.priority ?? Priority.NORMAL;
    final category = email.analysis?.category ?? EmailCategory.INFORMATION;
    final summary = email.analysis?.summary.trim();

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusTitle(email.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          email.subject.trim().isEmpty
                              ? '(No subject)'
                              : email.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tone.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatTime(email.date),
                    style: TextStyle(
                      color: tone.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _senderLine(email.from),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.text.withValues(alpha: 0.84),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(
                    label: _priorityLabel(priority),
                    color: _priorityColor(priority),
                  ),
                  _MiniBadge(
                    label: _categoryLabel(category),
                    color: _categoryColor(category),
                  ),
                  if (email.attachments.isNotEmpty)
                    _MiniBadge(
                      label:
                          '${email.attachments.length} attachment${email.attachments.length == 1 ? '' : 's'}',
                      color: AppPalette.blue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppPalette.amber,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final ActivityFilter filter;

  @override
  Widget build(BuildContext context) {
    final tone = _TodayTone.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(_emptyIcon(filter), size: 34, color: AppPalette.teal),
            ),
            const SizedBox(height: 18),
            Text(
              _emptyTitle(context, filter),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tone.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.t('today.refreshHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final now = DateTime.now();
  if (_isSameDay(date, now)) return l10n.t('today.title');
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(date, yesterday)) return l10n.t('today.yesterday');
  return '${date.day} ${_monthName(context, date.month)} ${date.year}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _monthName(BuildContext context, int month) {
  final l10n = context.l10n;
  final months = [
    l10n.t('date.jan'),
    l10n.t('date.feb'),
    l10n.t('date.mar'),
    l10n.t('date.apr'),
    l10n.t('date.may'),
    l10n.t('date.jun'),
    l10n.t('date.jul'),
    l10n.t('date.aug'),
    l10n.t('date.sep'),
    l10n.t('date.oct'),
    l10n.t('date.nov'),
    l10n.t('date.dec'),
  ];
  return months[month - 1];
}

String _senderLine(Sender sender) {
  final name = sender.name.trim();
  final email = sender.email.trim();
  if (name.isEmpty) return email.isEmpty ? 'Unknown sender' : email;
  if (email.isEmpty || email == name) return name;
  return '$name <$email>';
}

String _statusTitle(Status status) {
  switch (status) {
    case Status.DONE:
      return 'Reply sent';
    case Status.PENDING_USER_REVIEW:
      return 'Waiting for review';
    case Status.PENDING_JURY:
      return 'Checking draft';
    case Status.PENDING_ANALYSIS:
      return 'Preparing draft';
  }
}

IconData _statusIcon(Status status) {
  switch (status) {
    case Status.DONE:
      return Icons.mark_email_read_outlined;
    case Status.PENDING_USER_REVIEW:
      return Icons.rate_review_outlined;
    case Status.PENDING_JURY:
      return Icons.fact_check_outlined;
    case Status.PENDING_ANALYSIS:
      return Icons.auto_awesome_outlined;
  }
}

Color _statusColor(Status status) {
  switch (status) {
    case Status.DONE:
      return AppPalette.teal;
    case Status.PENDING_USER_REVIEW:
      return AppPalette.clay;
    case Status.PENDING_JURY:
      return AppPalette.blue;
    case Status.PENDING_ANALYSIS:
      return AppPalette.amber;
  }
}

String _priorityLabel(Priority priority) {
  switch (priority) {
    case Priority.URGENT:
      return 'URGENT';
    case Priority.NORMAL:
      return 'NORMAL';
    case Priority.LOW:
      return 'LOW';
  }
}

Color _priorityColor(Priority priority) {
  switch (priority) {
    case Priority.URGENT:
      return AppPalette.clay;
    case Priority.NORMAL:
      return AppPalette.amber;
    case Priority.LOW:
      return AppPalette.deepTeal;
  }
}

String _categoryLabel(EmailCategory category) {
  switch (category) {
    case EmailCategory.RECLAMATION:
      return 'RECLAMATION';
    case EmailCategory.COMMERCIAL:
      return 'COMMERCIAL';
    case EmailCategory.SUPPORT:
      return 'SUPPORT';
    case EmailCategory.INFORMATION:
      return 'INFO';
  }
}

Color _categoryColor(EmailCategory category) {
  switch (category) {
    case EmailCategory.RECLAMATION:
      return AppPalette.clay;
    case EmailCategory.COMMERCIAL:
      return AppPalette.deepTeal;
    case EmailCategory.SUPPORT:
      return AppPalette.amber;
    case EmailCategory.INFORMATION:
      return AppPalette.blue;
  }
}

String _emptyTitle(BuildContext context, ActivityFilter filter) {
  final l10n = context.l10n;
  switch (filter) {
    case ActivityFilter.all:
      return l10n.t('today.emptyAll');
    case ActivityFilter.autoSent:
      return l10n.t('today.emptySent');
    case ActivityFilter.review:
      return l10n.t('today.emptyReview');
    case ActivityFilter.low:
      return l10n.t('today.emptyLow');
  }
}

IconData _emptyIcon(ActivityFilter filter) {
  switch (filter) {
    case ActivityFilter.all:
      return Icons.inbox_outlined;
    case ActivityFilter.autoSent:
      return Icons.send_outlined;
    case ActivityFilter.review:
      return Icons.rate_review_outlined;
    case ActivityFilter.low:
      return Icons.low_priority_outlined;
  }
}
