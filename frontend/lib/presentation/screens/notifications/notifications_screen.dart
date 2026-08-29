import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/notification_center_view_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationCenterViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<NotificationCenterViewModel>();
    _viewModel.addListener(_onChanged);
    _viewModel.load();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationsHeader(
              urgentCount: _viewModel.urgentCount,
              readyCount: _viewModel.readyCount,
              editCount: _viewModel.editCount,
              lastUpdated: _viewModel.lastUpdated,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (_viewModel.state == LoadState.error)
              _InlineBanner(
                message:
                    _viewModel.errorMessage ??
                    'Unable to load notifications. Pull down to retry.',
              ),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: _viewModel.refresh,
                        child:
                            _viewModel.items.isEmpty
                                ? const _EmptyNotifications()
                                : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    28,
                                  ),
                                  itemCount: _viewModel.items.length,
                                  itemBuilder: (context, index) {
                                    final item = _viewModel.items[index];
                                    return _NotificationCard(
                                      item: item,
                                      onTap: () => _openEmail(item.email),
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

  Future<void> _openEmail(Email email) async {
    final mode =
        email.status == Status.PENDING_USER_REVIEW
            ? EmailDetailMode.edit
            : EmailDetailMode.readOnly;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => EmailDetailScreen(email: email, mode: mode),
      ),
    );
    if (changed == true && mounted) {
      await _viewModel.refresh();
    }
  }
}

class _NotificationTone {
  const _NotificationTone({
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

  static _NotificationTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _NotificationTone(
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

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.urgentCount,
    required this.readyCount,
    required this.editCount,
    required this.lastUpdated,
    required this.onBack,
  });

  final int urgentCount;
  final int readyCount;
  final int editCount;
  final DateTime? lastUpdated;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tone = _NotificationTone.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: tone.text,
              ),
              Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              lastUpdated == null
                  ? 'Your review queue and recent email activity.'
                  : 'Updated ${_formatShortTime(lastUpdated!)}',
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderPill(
                  label: '$urgentCount urgent',
                  color: AppPalette.clay,
                  icon: Icons.priority_high_rounded,
                ),
                _HeaderPill(
                  label: '$readyCount ready',
                  color: AppPalette.teal,
                  icon: Icons.verified_outlined,
                ),
                _HeaderPill(
                  label: '$editCount needs edit',
                  color: AppPalette.amber,
                  icon: Icons.edit_note_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationCenterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _NotificationTone.of(context);
    final color = _kindColor(item.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_kindIcon(item.kind), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: tone.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(item.email.date),
                            style: TextStyle(
                              color: tone.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tone.text.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniBadge(
                            label: _kindLabel(item.kind),
                            color: color,
                          ),
                          _MiniBadge(
                            label: _senderLabel(item.email.from),
                            color: AppPalette.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: tone.muted, size: 24),
              ],
            ),
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
      constraints: const BoxConstraints(maxWidth: 180),
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

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = _NotificationTone.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final tone = _NotificationTone.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 90, 32, 28),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppPalette.teal,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Nothing needs attention',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tone.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Replies ready for review, urgent emails, and recent sent activity will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tone.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

String _formatShortTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

String _senderLabel(Sender sender) {
  final name = sender.name.trim();
  if (name.isNotEmpty) return name;
  final email = sender.email.trim();
  return email.isEmpty ? 'Unknown sender' : email;
}

String _kindLabel(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.ready:
      return 'READY';
    case NotificationKind.urgent:
      return 'URGENT';
    case NotificationKind.needsEdit:
      return 'NEEDS EDIT';
    case NotificationKind.processing:
      return 'PROCESSING';
    case NotificationKind.sent:
      return 'SENT';
  }
}

IconData _kindIcon(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.ready:
      return Icons.verified_outlined;
    case NotificationKind.urgent:
      return Icons.priority_high_rounded;
    case NotificationKind.needsEdit:
      return Icons.edit_note_rounded;
    case NotificationKind.processing:
      return Icons.sync_rounded;
    case NotificationKind.sent:
      return Icons.send_rounded;
  }
}

Color _kindColor(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.ready:
      return AppPalette.teal;
    case NotificationKind.urgent:
      return AppPalette.clay;
    case NotificationKind.needsEdit:
      return AppPalette.amber;
    case NotificationKind.processing:
      return AppPalette.blue;
    case NotificationKind.sent:
      return AppPalette.deepTeal;
  }
}
