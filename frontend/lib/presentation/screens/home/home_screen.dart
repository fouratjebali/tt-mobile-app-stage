import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/bulk_email/bulk_email_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<HomeViewModel>();
    _viewModel.addListener(_onChanged);
    _viewModel.loadSummary();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        _viewModel.state == LoadState.loading ||
        _viewModel.state == LoadState.idle;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _viewModel.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _GreetingHeader(
                        userName: _viewModel.userName,
                        userEmail: _viewModel.userEmail,
                        userPhotoUrl: _viewModel.userPhotoUrl,
                      ),
                      const SizedBox(height: 20),
                      _ReviewSummaryCard(count: _viewModel.needReview),
                      const SizedBox(height: 18),
                      _KPIGrid(
                        processedToday: _viewModel.processedToday,
                        autoSent: _viewModel.autoSent,
                        needReview: _viewModel.needReview,
                        accuracyRate: _viewModel.accuracyRate,
                      ),
                      if (_viewModel.state == LoadState.error) ...[
                        const SizedBox(height: 16),
                        _InlineNotice(
                          icon: Icons.cloud_off_outlined,
                          message: _viewModel.errorMessage ?? 'Error',
                          color: Colors.orange,
                        ),
                      ],
                      const SizedBox(height: 28),
                      const _SectionTitle(
                        title: 'Recent activity',
                        actionLabel: 'Today',
                      ),
                      const SizedBox(height: 12),
                      if (_viewModel.recentEmails.isEmpty)
                        const _EmptyPanel(
                          icon: Icons.inbox_outlined,
                          title: 'No recent activity',
                          subtitle: 'Processed emails will appear here.',
                        )
                      else
                        ..._viewModel.recentEmails.map(
                          (email) => _ActivityCard(
                            email: email,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => EmailDetailScreen(email: email),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 28),
                      const _SectionTitle(
                        title: 'Shortcuts',
                        actionLabel: 'Tools',
                      ),
                      const SizedBox(height: 12),
                      _ShortcutsRow(),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userName,
    required this.userEmail,
    required this.userPhotoUrl,
  });

  final String userName;
  final String? userEmail;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    final greeting =
        now.hour < 12
            ? 'Good morning'
            : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $userName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _formatDate(now),
                style: TextStyle(
                  fontSize: 14,
                  color: AppPalette.pine.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        CircleAvatar(
          radius: 25,
          backgroundColor: AppPalette.sage,

          backgroundImage:
              userPhotoUrl == null ? null : NetworkImage(userPhotoUrl!),

          child:
              userPhotoUrl == null
                  ? Text(
                    _initials(userName, userEmail),
                    style: const TextStyle(
                      color: AppPalette.pine,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                  : null,
        ),
      ],
    );
  }

  String _initials(String name, String? email) {
    final source = name.trim().isNotEmpty ? name.trim() : (email ?? '').trim();

    if (source.isEmpty) return '?';

    final parts = source.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${date.day} ${months[date.month - 1]}';
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hasReview = count > 0;
    final accent = hasReview ? AppPalette.clay : AppPalette.deepTeal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasReview
                  ? Icons.mark_email_unread_outlined
                  : Icons.task_alt_outlined,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasReview
                      ? '$count replies need review'
                      : 'Inbox is under control',
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasReview
                      ? 'Open Review to check drafts before sending.'
                      : 'New unread emails will appear here after the agents process them.',
                  style: TextStyle(
                    color: AppPalette.pine.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KPIGrid extends StatelessWidget {
  const _KPIGrid({
    required this.processedToday,
    required this.autoSent,
    required this.needReview,
    required this.accuracyRate,
  });

  final int processedToday;
  final int autoSent;
  final int needReview;
  final double accuracyRate;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,

      children: [
        _KPICard(
          title: 'Processed today',
          value: processedToday.toString(),
          color: AppPalette.deepTeal,
          icon: Icons.check_circle_outline,
        ),

        _KPICard(
          title: 'Confident',
          value: autoSent.toString(),
          color: AppPalette.blue,
          icon: Icons.auto_awesome,
        ),

        _KPICard(
          title: 'Need review',
          value: needReview.toString(),
          color: AppPalette.clay,
          icon: Icons.rate_review_outlined,
        ),

        _KPICard(
          title: 'Completion',
          value: '${accuracyRate.toStringAsFixed(0)}%',
          color: AppPalette.amber,
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  const _KPICard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.pine.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          actionLabel,
          style: TextStyle(
            color: AppPalette.pine.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.email, required this.onTap});

  final Email email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priority = email.analysis?.priority ?? Priority.NORMAL;

    final category = email.analysis?.category ?? EmailCategory.INFORMATION;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.all(15),

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
                            email.subject.isEmpty
                                ? '(No subject)'
                                : email.subject,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: AppPalette.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _senderLabel(email.from),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.pine.withValues(alpha: 0.64),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    _Badge(
                      label: _categoryLabel(category),
                      color: _categoryColor(category),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,

                  children: [
                    _Badge(
                      label: _priorityLabel(priority),
                      color: _priorityColor(priority),
                    ),

                    _Badge(
                      label: _statusLabel(email.status),
                      color: AppPalette.deepTeal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _senderLabel(Sender sender) {
    if (sender.name.trim().isNotEmpty) {
      return sender.name;
    }

    if (sender.email.trim().isNotEmpty) {
      return sender.email;
    }

    return 'Unknown sender';
  }
}

class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutButton(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _ShortcutButton(
            icon: Icons.mail_outline,
            label: 'Bulk Email',

            // =================================================
            // BULK EMAIL S10
            // =================================================
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkEmailScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppPalette.sage.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppPalette.deepTeal, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.pine,
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),

      child: Row(
        children: [
          Icon(icon, size: 20, color: color),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,

              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),

      decoration: BoxDecoration(
        color: AppPalette.paper,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppPalette.line),
      ),

      child: Column(
        children: [
          Icon(icon, size: 38, color: AppPalette.pine.withValues(alpha: 0.38)),

          const SizedBox(height: 12),

          Text(
            title,

            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              color: AppPalette.pine.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),

      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(
        label,

        maxLines: 1,

        overflow: TextOverflow.ellipsis,

        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
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

String _statusLabel(Status status) {
  switch (status) {
    case Status.DONE:
      return 'DONE';

    case Status.PENDING_USER_REVIEW:
      return 'REVIEW';

    case Status.PENDING_JURY:
      return 'JURY';

    case Status.PENDING_ANALYSIS:
      return 'ANALYSIS';
  }
}
