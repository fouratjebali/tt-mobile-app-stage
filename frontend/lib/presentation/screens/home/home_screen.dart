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
                      _ReviewFocusCard(
                        needReview: _viewModel.needReview,
                        onTap: () => widget.onSelectTab?.call(2),
                      ),
                      const SizedBox(height: 12),
                      _HomeStatsStrip(
                        processed: _viewModel.processedToday,
                        sent: _viewModel.autoSent,
                        completionRate: _viewModel.accuracyRate,
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
                      _ShortcutRail(
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
                  fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w600,
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

class _ReviewFocusCard extends StatelessWidget {
  const _ReviewFocusCard({required this.needReview, required this.onTap});

  final int needReview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _HomeTone.of(context);
    final l10n = context.l10n;
    final hasWork = needReview > 0;
    final accent = hasWork ? const Color(0xFFE5484D) : AppPalette.deepTeal;

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 158),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasWork ? accent.withValues(alpha: 0.28) : tone.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: hasWork ? 0.13 : 0.11),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child:
                        hasWork
                            ? _UrgentKPIIcon(
                              icon: Icons.priority_high_rounded,
                              color: accent,
                            )
                            : Icon(
                              Icons.task_alt_rounded,
                              size: 25,
                              color: accent,
                            ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: tone.muted),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                hasWork
                    ? l10n.t('home.reviewCardTitle')
                    : l10n.t('home.reviewCardClearTitle'),
                style: TextStyle(
                  color: tone.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasWork
                    ? l10n
                        .t('home.reviewCardSubtitle')
                        .replaceAll('{count}', '$needReview')
                    : l10n.t('home.reviewCardClearSubtitle'),
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    needReview.toString(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('home.repliesNeedReview'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.t('home.reviewNow'),
                      style: const TextStyle(
                        color: AppPalette.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _HomeStatsStrip extends StatelessWidget {
  const _HomeStatsStrip({
    required this.processed,
    required this.sent,
    required this.completionRate,
  });

  final int processed;
  final int sent;
  final double completionRate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _CompactStat(
            icon: Icons.mark_email_read_outlined,
            title: l10n.t('home.processedToday'),
            value: processed.toString(),
            color: AppPalette.deepTeal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStat(
            icon: Icons.send_outlined,
            title: l10n.t('home.sent'),
            value: sent.toString(),
            color: AppPalette.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStat(
            icon: Icons.insights_rounded,
            title: l10n.t('home.completion'),
            value: '${completionRate.toStringAsFixed(0)}%',
            color: AppPalette.amber,
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
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
    final tone = _HomeTone.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: tone.text,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tone.muted,
              height: 1.2,
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          actionLabel,
          style: TextStyle(
            color: tone.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
                              fontWeight: FontWeight.w600,
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

class _ShortcutRail extends StatelessWidget {
  const _ShortcutRail({required this.onReviewTap, this.onSelectTab});

  final VoidCallback onReviewTap;
  final ValueChanged<int>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 126,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _ShortcutTile(
            icon: Icons.school_outlined,
            label: l10n.t('home.formations'),
            subtitle: l10n.t('home.formationsShortcutShort'),
            color: AppPalette.deepTeal,
            onTap: () async {
              final selectedTab = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormationsScreen(),
                ),
              );
              if (selectedTab != null && context.mounted) {
                onSelectTab?.call(selectedTab);
              }
            },
          ),
          _ShortcutTile(
            icon: Icons.mail_outline_rounded,
            label: l10n.t('home.groupDrafts'),
            subtitle: l10n.t('home.groupDraftsShortcutShort'),
            color: AppPalette.blue,
            onTap: () async {
              final selectedTab = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkEmailScreen(),
                ),
              );
              if (selectedTab != null && context.mounted) {
                onSelectTab?.call(selectedTab);
              }
            },
          ),
          _ShortcutTile(
            icon: Icons.rate_review_outlined,
            label: l10n.t('home.reviewReplies'),
            subtitle: l10n.t('home.reviewRepliesShortcutShort'),
            color: AppPalette.clay,
            onTap: onReviewTap,
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
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
      child: Container(
        width: 154,
        margin: const EdgeInsets.only(right: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tone.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tone.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.22,
                    color: tone.muted,
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
              fontWeight: FontWeight.w600,
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
          fontWeight: FontWeight.w600,
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
