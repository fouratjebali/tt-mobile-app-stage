import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<ReviewViewModel>();
    _viewModel.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel.loadReviewEmails();
      }
    });
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
    final emails = _viewModel.sortedEmails;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewHeader(pendingCount: _viewModel.pendingCount),
            if (_viewModel.state == LoadState.error)
              _ErrorBanner(message: _viewModel.errorMessage ?? 'Error'),
            if (_viewModel.actionErrorMessage != null)
              _ActionErrorBanner(
                message: _viewModel.actionErrorMessage!,
                onRetry: _viewModel.retryLastAction,
              ),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : emails.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                        onRefresh: _viewModel.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: emails.length,
                          itemBuilder: (context, index) {
                            return _ReviewEmailCard(
                              email: emails[index],
                              isSubmitting: _viewModel.isSubmittingAction,
                              onSendReply:
                                  () => _viewModel.validateAndSend(
                                    emails[index].id,
                                  ),
                              onEditFirst:
                                  () => _showEditAndSendDialog(
                                    context,
                                    emails[index],
                                  ),
                              onReject: () => _confirmReject(emails[index]),
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

  Future<void> _showEditAndSendDialog(BuildContext context, Email email) async {
    final controller = TextEditingController(
      text: email.analysis?.suggestedReply ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit & send'),
            content: TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Write your reply…',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send'),
              ),
            ],
          ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await _viewModel.editAndSend(email.id, controller.text.trim());
    }
  }

  Future<void> _confirmReject(Email email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Do not respond'),
            content: const Text(
              'Mark this email as handled without sending a reply?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _viewModel.reject(email.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Review',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pendingCount pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Emails that need your validation',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Email card
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewEmailCard extends StatelessWidget {
  const _ReviewEmailCard({
    required this.email,
    required this.onSendReply,
    required this.onEditFirst,
    required this.onReject,
    required this.isSubmitting,
  });

  final Email email;
  final VoidCallback onSendReply;
  final VoidCallback onEditFirst;
  final VoidCallback onReject;
  final bool isSubmitting;

  Priority get _priority => email.analysis?.priority ?? Priority.NORMAL;

  Color get _priorityColor {
    switch (_priority) {
      case Priority.URGENT:
        return const Color(0xFFE53935);
      case Priority.NORMAL:
        return const Color(0xFFF57C00);
      case Priority.LOW:
        return const Color(0xFF43A047);
    }
  }

  String get _priorityLabel {
    switch (_priority) {
      case Priority.URGENT:
        return 'URGENT';
      case Priority.NORMAL:
        return 'NORMAL';
      case Priority.LOW:
        return 'LOW';
    }
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _buildReason() {
    final parts = <String>[];
    if (_priority == Priority.URGENT) {
      parts.add('Priority = URGENT');
    }
    final jury = email.jury;
    if (jury != null && jury.reasoning != null && jury.reasoning!.isNotEmpty) {
      parts.add(jury.reasoning!);
    } else if (email.analysis != null) {
      final conf = (email.analysis!.confidence * 100).toStringAsFixed(0);
      parts.add('Jury confidence $conf% — below 80% threshold');
    }
    return parts.isEmpty ? 'Manual review required' : parts.join(' — ');
  }

  String get _emailPreview {
    final body = email.body.plain.trim();
    if (body.isNotEmpty) return body;
    return 'No preview available.';
  }

  String get _suggestedReply {
    final suggested = email.analysis?.suggestedReply.trim() ?? '';
    if (suggested.isNotEmpty) return suggested;
    return 'No suggested reply was generated yet.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: _priorityColor, width: 4)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PriorityBadge(label: _priorityLabel, color: _priorityColor),
                Text(
                  '● ${_formatRelativeTime(email.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              email.subject,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              email.from.email,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Text(
              'Reason: ${_buildReason()}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _ReviewTextBlock(title: 'Email', text: _emailPreview, maxLines: 4),
            const SizedBox(height: 10),
            _ReviewTextBlock(
              title: 'Suggested reply',
              text: _suggestedReply,
              maxLines: 5,
              highlighted: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isSubmitting ? null : onSendReply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.lavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Send reply'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSubmitting ? null : onEditFirst,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.lavender,
                      side: BorderSide(
                        color: AppPalette.lavender.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Edit first'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isSubmitting ? null : onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text("Don't respond"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Priority badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewTextBlock extends StatelessWidget {
  const _ReviewTextBlock({
    required this.title,
    required this.text,
    required this.maxLines,
    this.highlighted = false,
  });

  final String title;
  final String text;
  final int maxLines;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlighted
            ? AppPalette.lavender.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.18);
    final background =
        highlighted
            ? AppPalette.lavender.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlighted ? AppPalette.lavender : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppPalette.teal.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tout est traité',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No emails need your attention right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionErrorBanner extends StatelessWidget {
  const _ActionErrorBanner({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
