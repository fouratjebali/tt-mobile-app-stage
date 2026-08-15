import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/bulk_email/bulk_email_screen.dart';
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _GreetingHeader(
                        userName: _viewModel.userName,
                        userEmail: _viewModel.userEmail,
                        userPhotoUrl: _viewModel.userPhotoUrl,
                      ),
                      const SizedBox(height: 20),
                      _KPIGrid(
                        processedToday: _viewModel.processedToday,
                        autoSent: _viewModel.autoSent,
                        needReview: _viewModel.needReview,
                        accuracyRate: _viewModel.accuracyRate,
                      ),
                      const SizedBox(height: 16),
                      _AgentStatusCard(
                        isActive: _viewModel.agentActive,
                        onChanged: _viewModel.toggleAgent,
                      ),
                      if (_viewModel.state == LoadState.error) ...[
                        const SizedBox(height: 16),
                        _InlineNotice(
                          icon: Icons.cloud_off_outlined,
                          message: _viewModel.errorMessage ?? 'Error',
                          color: Colors.orange,
                        ),
                      ],
                      if (_viewModel.needReview > 0) ...[
                        const SizedBox(height: 16),
                        _ActionRequiredBanner(count: _viewModel.needReview),
                      ],
                      const SizedBox(height: 24),
                      const _SectionTitle(title: 'Recent Activity'),
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
                      const SizedBox(height: 24),
                      const _SectionTitle(title: 'Quick Actions'),
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

    final greeting =
        now.hour < 12
            ? 'Good morning'
            : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $userName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _formatDate(now),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        CircleAvatar(
          radius: 24,
          backgroundColor: AppPalette.lavender.withValues(alpha: 0.22),

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
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.28,

      children: [
        _KPICard(
          title: 'Processed',
          value: processedToday.toString(),
          color: Colors.green,
          icon: Icons.check_circle_outline,
        ),

        _KPICard(
          title: 'Auto-ready',
          value: autoSent.toString(),
          color: AppPalette.teal,
          icon: Icons.auto_awesome,
        ),

        _KPICard(
          title: 'Need review',
          value: needReview.toString(),
          color: Colors.red,
          icon: Icons.priority_high,
        ),

        _KPICard(
          title: 'Completion',
          value: '${accuracyRate.toStringAsFixed(0)}%',
          color: Colors.indigo,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                Icon(icon, size: 20, color: color),
              ],
            ),

            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentStatusCard extends StatelessWidget {
  const _AgentStatusCard({required this.isActive, required this.onChanged});

  final bool isActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.orange;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color: color,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Agent Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isActive ? 'Active' : 'Paused',
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            Switch(
              value: isActive,
              onChanged: onChanged,
              activeColor: AppPalette.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRequiredBanner extends StatelessWidget {
  const _ActionRequiredBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),

      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade600, size: 22),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              '$count email${count > 1 ? 's' : ''} '
              'need${count > 1 ? '' : 's'} '
              'your attention',

              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(14),

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
                            color: Colors.grey[600],
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
                    color: AppPalette.teal,
                  ),
                ],
              ),
            ],
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
            onTap: () => _showPending(context),
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

  void _showPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This workspace is being prepared.')),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),

        decoration: BoxDecoration(
          color: AppPalette.lavender.withValues(alpha: 0.12),

          borderRadius: BorderRadius.circular(8),

          border: Border.all(
            color: AppPalette.lavender.withValues(alpha: 0.24),
          ),
        ),

        child: Column(
          children: [
            Icon(icon, color: AppPalette.teal, size: 26),

            const SizedBox(height: 8),

            Text(
              label,

              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.pine,
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(8),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),

      child: Column(
        children: [
          Icon(icon, size: 38, color: Colors.grey[500]),

          const SizedBox(height: 12),

          Text(
            title,

            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
        borderRadius: BorderRadius.circular(6),
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
      return Colors.red;

    case EmailCategory.COMMERCIAL:
      return Colors.green;

    case EmailCategory.SUPPORT:
      return Colors.orange;

    case EmailCategory.INFORMATION:
      return Colors.blue;
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
      return Colors.red;

    case Priority.NORMAL:
      return Colors.orange;

    case Priority.LOW:
      return Colors.green;
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
