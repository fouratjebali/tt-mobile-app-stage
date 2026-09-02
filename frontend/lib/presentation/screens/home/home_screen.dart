import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/core/utils/avatar_image_provider.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/bulk_email/bulk_email_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/formations/formations_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/notifications/notifications_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSelectTab});

  final ValueChanged<int>? onSelectTab;

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
    final l10n = context.l10n;

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
                        notificationCount: _viewModel.needReview,
                        onNotificationsTap: _openNotifications,
                      ),
                      const SizedBox(height: 20),
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
                          message:
                              _viewModel.errorMessage ?? l10n.t('home.error'),
                          color: Colors.orange,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _SectionTitle(
                        title: l10n.t('home.recentActivity'),
                        actionLabel: l10n.t('nav.today'),
                      ),
                      const SizedBox(height: 12),
                      if (_viewModel.recentEmails.isEmpty)
                        _EmptyPanel(
                          icon: Icons.inbox_outlined,
                          title: l10n.t('home.noRecentActivity'),
                          subtitle: l10n.t('home.processedAppear'),
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
                      _SectionTitle(
                        title: l10n.t('home.shortcuts'),
                        actionLabel: l10n.t('home.tools'),
                      ),
                      const SizedBox(height: 12),
                      _ShortcutsRow(
                        onReviewTap: () => widget.onSelectTab?.call(2),
                        onSelectTab: widget.onSelectTab,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) {
      _viewModel.refresh();
    }
  }
}

class _HomeTone {
  const _HomeTone({
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

  static _HomeTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HomeTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
      softSurface:
          isDark
              ? AppPalette.white.withValues(alpha: 0.06)
              : AppPalette.sage.withValues(alpha: 0.65),
      border:
          isDark ? AppPalette.white.withValues(alpha: 0.08) : AppPalette.line,
      text: isDark ? AppPalette.white : AppPalette.ink,
      muted:
          isDark
              ? AppPalette.white.withValues(alpha: 0.64)
              : AppPalette.pine.withValues(alpha: 0.68),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userName,
    required this.userEmail,
    required this.userPhotoUrl,
    required this.notificationCount,
    required this.onNotificationsTap,
  });

  final String userName;
  final String? userEmail;
  final String? userPhotoUrl;
  final int notificationCount;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final tone = _HomeTone.of(context);
    final l10n = context.l10n;
    final avatarImage = avatarImageProvider(userPhotoUrl);

    final greeting =
        now.hour < 12
            ? l10n.t('home.goodMorning')
            : now.hour < 18
            ? l10n.t('home.goodAfternoon')
            : l10n.t('home.goodEvening');

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
                _formatDate(context, now),
                style: TextStyle(
                  fontSize: 14,
                  color: tone.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        _NotificationIconButton(
          count: notificationCount,
          onTap: onNotificationsTap,
        ),

        const SizedBox(width: 10),

        CircleAvatar(
          radius: 25,
          backgroundColor: tone.softSurface,
          backgroundImage: avatarImage,
          child:
              avatarImage == null
                  ? Text(
                    _initials(userName, userEmail),
                    style: TextStyle(
                      color: tone.text,
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

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = context.l10n;
    final weekdays = [
      l10n.t('date.monday'),
      l10n.t('date.tuesday'),
      l10n.t('date.wednesday'),
      l10n.t('date.thursday'),
      l10n.t('date.friday'),
      l10n.t('date.saturday'),
      l10n.t('date.sunday'),
    ];

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

    return '${weekdays[date.weekday - 1]}, '
        '${date.day} ${months[date.month - 1]}';
  }
}

class _NotificationIconButton extends StatelessWidget {
  const _NotificationIconButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _HomeTone.of(context);

    return Tooltip(
      message: context.l10n.t('home.notifications'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tone.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: tone.text,
                  size: 23,
                ),
                if (count > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.clay,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tone.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: AppPalette.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
    final l10n = context.l10n;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,

      children: [
        _KPICard(
          title: l10n.t('home.needReview'),
          value: needReview.toString(),
          color: const Color(0xFFE5484D),
          icon: Icons.warning_amber_rounded,
          pulse: needReview > 0,
        ),

        _KPICard(
          title: l10n.t('home.processedToday'),
          value: processedToday.toString(),
          color: AppPalette.deepTeal,
          icon: Icons.check_circle_outline,
        ),

        _KPICard(
          title: l10n.t('home.sent'),
          value: autoSent.toString(),
          color: AppPalette.blue,
          icon: Icons.send_outlined,
        ),

        _KPICard(
          title: l10n.t('home.completion'),
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
    this.pulse = false,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final tone = _HomeTone.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
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
            child:
                pulse
                    ? _UrgentKPIIcon(icon: icon, color: color)
                    : Icon(icon, size: 19, color: color),
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
                    color: tone.muted,
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

class _UrgentKPIIcon extends StatefulWidget {
  const _UrgentKPIIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_UrgentKPIIcon> createState() => _UrgentKPIIconState();
}

class _UrgentKPIIconState extends State<_UrgentKPIIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.18,
      end: 0.42,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glow.value),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: Icon(widget.icon, size: 20, color: widget.color),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final tone = _HomeTone.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tone.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          actionLabel,
          style: TextStyle(
            color: tone.muted,
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
    final tone = _HomeTone.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
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
                                ? context.l10n.t('home.noSubject')
                                : email.subject,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              color: tone.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _senderLabel(context, email.from),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 12,
                              color: tone.muted,
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

  String _senderLabel(BuildContext context, Sender sender) {
    if (sender.name.trim().isNotEmpty) {
      return sender.name;
    }

    if (sender.email.trim().isNotEmpty) {
      return sender.email;
    }

    return context.l10n.t('home.unknownSender');
  }
}

class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({required this.onReviewTap, this.onSelectTab});

  final VoidCallback onReviewTap;
  final ValueChanged<int>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _ShortcutButton(
          icon: Icons.rate_review_outlined,
          label: l10n.t('home.reviewReplies'),
          subtitle: l10n.t('home.reviewRepliesShortcut'),
          color: AppPalette.deepTeal,
          onTap: onReviewTap,
        ),
        const SizedBox(height: 10),
        _ShortcutButton(
          icon: Icons.mail_outline_rounded,
          label: l10n.t('home.groupDrafts'),
          subtitle: l10n.t('home.groupDraftsShortcut'),
          color: AppPalette.blue,
          onTap: () async {
            final selectedTab = await Navigator.push<int>(
              context,
              MaterialPageRoute(builder: (context) => const BulkEmailScreen()),
            );
            if (selectedTab != null && context.mounted) {
              onSelectTab?.call(selectedTab);
            }
          },
        ),
        const SizedBox(height: 10),
        _ShortcutButton(
          icon: Icons.school_outlined,
          label: l10n.t('home.formations'),
          subtitle: l10n.t('home.formationsShortcut'),
          color: AppPalette.clay,
          onTap: () async {
            final selectedTab = await Navigator.push<int>(
              context,
              MaterialPageRoute(builder: (context) => const FormationsScreen()),
            );
            if (selectedTab != null && context.mounted) {
              onSelectTab?.call(selectedTab);
            }
          },
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _HomeTone.of(context);

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: tone.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: tone.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: tone.muted),
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
    final tone = _HomeTone.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),

      decoration: BoxDecoration(
        color: tone.surface,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: tone.border),
      ),

      child: Column(
        children: [
          Icon(icon, size: 38, color: tone.muted.withValues(alpha: 0.62)),

          const SizedBox(height: 12),

          Text(
            title,

            style: TextStyle(
              color: tone.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 13, color: tone.muted),
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
