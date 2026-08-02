import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';
import 'package:tt_mail_assistant/presentation/screens/prompt/prompt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late EmailUseCase _emailUseCase;
  late SettingsRepository _settingsRepository;
  late AuthRepository _authRepository;

  String? userName;
  bool agentActive = true;
  List<Email> recentEmails = [];
  bool isLoading = true;

  // KPI data
  int processedToday = 0;
  int autoSent = 0;
  int needReview = 0;
  double accuracyRate = 0;

  @override
  void initState() {
    super.initState();
    _emailUseCase = getIt<EmailUseCase>();
    _settingsRepository = getIt<SettingsRepository>();
    _authRepository = getIt<AuthRepository>();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = await _authRepository.getCurrentUser();
      final emails = await _emailUseCase.getEmails();

      if (!mounted) return;

      // Calculate KPIs
      int processed = 0;
      int autoSent = 0;
      int review = 0;

      for (final email in emails) {
        if (email.status == Status.DONE) processed++;
        if ((email.analysis?.confidence ?? 0.0) > 0.8) autoSent++;
        if (email.status == Status.PENDING_USER_REVIEW) review++;
      }

      final totalEmails = emails.length > 0 ? emails.length : 1;
      final accuracy = (processed / totalEmails) * 100;

      setState(() {
        if (user != null) {
          userName = (user.displayName ?? 'User').split(' ').first;
        } else {
          userName = 'User';
        }
        processedToday = processed;
        this.autoSent = autoSent;
        needReview = review;
        accuracyRate = accuracy;
        recentEmails = emails.take(3).toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAgent(bool value) async {
    setState(() {
      agentActive = value;
    });
    await _settingsRepository.setAutoProcessing(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // GREETING HEADER
                  _GreetingHeader(userName: userName ?? 'User'),
                  const SizedBox(height: 24),

                  // KPI CARDS
                  _KPIGrid(
                    processedToday: processedToday,
                    autoSent: autoSent,
                    needReview: needReview,
                    accuracyRate: accuracyRate,
                  ),
                  const SizedBox(height: 24),

                  // AGENT STATUS TOGGLE
                  _AgentStatusCard(
                    isActive: agentActive,
                    onChanged: _toggleAgent,
                  ),
                  const SizedBox(height: 24),

                  // ACTION REQUIRED BANNER (conditional)
                  if (needReview > 0)
                    _ActionRequiredBanner(
                      count: needReview,
                      onTap: () {
                        // Navigate to review screen
                      },
                    ),
                  if (needReview > 0) const SizedBox(height: 24),

                  // RECENT ACTIVITY SECTION
                  const _SectionTitle(title: 'Recent Activity'),
                  const SizedBox(height: 12),
                  if (recentEmails.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No recent activity'),
                      ),
                    )
                  else
                    ...recentEmails
                        .map((email) => _ActivityCard(email: email))
                        .toList(),
                  const SizedBox(height: 24),

                  // SHORTCUTS
                  const _SectionTitle(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _ShortcutsRow(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$greeting, $userName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            const Text('👋', style: TextStyle(fontSize: 24)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Saturday, 02 August',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KPICard(
          title: 'Processed today',
          value: processedToday.toString(),
          color: Colors.green,
          icon: Icons.check_circle,
        ),
        _KPICard(
          title: 'Auto-sent',
          value: autoSent.toString(),
          color: Colors.green,
          icon: Icons.send,
        ),
        _KPICard(
          title: 'Need review',
          value: needReview.toString(),
          color: Colors.red,
          icon: Icons.warning,
        ),
        _KPICard(
          title: 'Accuracy',
          value: '${accuracyRate.toStringAsFixed(0)}%',
          color: Colors.green,
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
  const _AgentStatusCard({
    required this.isActive,
    required this.onChanged,
  });

  final bool isActive;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agent Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? 'Active' : 'Paused',
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Switch(
              value: isActive,
              onChanged: (value) async {
                await onChanged(value);
              },
              activeColor: AppPalette.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRequiredBanner extends StatelessWidget {
  const _ActionRequiredBanner({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$count email${count > 1 ? 's' : ''} need${count > 1 ? '' : 's'} your attention',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Take action to keep your inbox organized',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
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
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.email});
  final Email email;

  String _getCategoryLabel(EmailCategory? category) {
    if (category == null) return 'INFO';
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

  Color _getCategoryColor(EmailCategory? category) {
    if (category == null) return Colors.blue;
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

  String _getPriorityLabel(Priority priority) {
    switch (priority) {
      case Priority.URGENT:
        return 'URGENT';
      case Priority.NORMAL:
        return 'NORMAL';
      case Priority.LOW:
        return 'LOW';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.URGENT:
        return Colors.red;
      case Priority.NORMAL:
        return Colors.orange;
      case Priority.LOW:
        return Colors.green;
    }
  }

  String _getStatusLabel(Status status) {
    switch (status) {
      case Status.DONE:
        return 'Auto-sent';
      case Status.PENDING_USER_REVIEW:
        return 'Review';
      case Status.PENDING_JURY:
        return 'Jury';
      case Status.PENDING_ANALYSIS:
        return 'Analysis';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = email.analysis?.priority ?? Priority.NORMAL;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        email.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.from.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(email.analysis?.category)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCategoryLabel(email.analysis?.category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          _getCategoryColor(email.analysis?.category),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getPriorityLabel(priority),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(priority),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.lavender.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(email.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutButton(
            icon: Icons.dashboard,
            label: 'Dashboard',
            onTap: () {
              // Navigate to dashboard
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutButton(
            icon: Icons.mail_outline,
            label: 'Bulk Email',
            onTap: () {
              // Navigate to bulk email
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppPalette.lavender.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppPalette.lavender.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppPalette.lavender, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
