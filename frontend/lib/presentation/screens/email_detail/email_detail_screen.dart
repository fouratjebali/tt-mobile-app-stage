import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/errors/error_message.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';

enum EmailDetailMode { readOnly, edit }

class EmailDetailScreen extends StatefulWidget {
  const EmailDetailScreen({
    super.key,
    required this.email,
    this.mode = EmailDetailMode.readOnly,
  });

  final Email email;
  final EmailDetailMode mode;

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  late final EmailUseCase _emailUseCase;
  late final TextEditingController _replyController;
  bool _isSubmitting = false;
  String? _actionError;

  bool get _isEditMode => widget.mode == EmailDetailMode.edit;

  @override
  void initState() {
    super.initState();
    _emailUseCase = getIt<EmailUseCase>();
    _replyController = TextEditingController(text: _initialReply);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String get _initialReply {
    final suggested = widget.email.analysis?.suggestedReply.trim() ?? '';
    if (suggested.isNotEmpty) return suggested;
    return 'Bonjour,\n\nMerci pour votre message. Nous allons le consulter et revenir vers vous rapidement.\n\nCordialement,';
  }

  Future<void> _sendReply({required bool edited}) async {
    final body = _replyController.text.trim();
    if (body.isEmpty) {
      setState(() => _actionError = 'Reply cannot be empty.');
      return;
    }

    final confirmed = await _confirmAction(
      title: edited ? 'Send edited reply?' : 'Send reply?',
      message:
          edited
              ? 'Send the edited reply to this sender?'
              : 'Send the suggested reply to this sender?',
      confirmLabel: 'Send',
    );
    if (confirmed != true) return;

    await _runAction(() {
      return edited
          ? _emailUseCase.editAndSend(emailId: widget.email.id, body: body)
          : _emailUseCase.validateAndSend(emailId: widget.email.id, body: body);
    }, successMessage: 'Reply sent.');
  }

  Future<void> _ignoreEmail() async {
    final confirmed = await _confirmAction(
      title: 'Skip reply?',
      message: 'Mark this email as handled without sending a reply?',
      confirmLabel: 'Skip',
      destructive: true,
    );
    if (confirmed != true) return;

    await _runAction(
      () => _emailUseCase.reject(emailId: widget.email.id),
      successMessage: 'Email marked as handled.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _actionError = null;
    });

    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = ErrorMessage.fromException(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final tone = _DetailTone.of(context);

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: tone.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: tone.border),
            ),
            title: Text(
              title,
              style: TextStyle(color: tone.text, fontWeight: FontWeight.w900),
            ),
            content: Text(
              message,
              style: TextStyle(color: tone.muted, height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: tone.muted)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    destructive
                        ? FilledButton.styleFrom(
                          backgroundColor: AppPalette.clay,
                        )
                        : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final priority = widget.email.analysis?.priority ?? Priority.NORMAL;
    final category =
        widget.email.analysis?.category ?? EmailCategory.INFORMATION;
    final body = widget.email.body.plain.trim();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar:
          _isEditMode
              ? _ActionBar(
                isSubmitting: _isSubmitting,
                onSend: () => _sendReply(edited: false),
                onEditSend: () => _sendReply(edited: true),
                onSkip: _ignoreEmail,
              )
              : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DetailTopBar(
                title: _isEditMode ? 'Review reply' : 'Email',
                status: widget.email.status,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, _isEditMode ? 18 : 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MessageHero(
                    email: widget.email,
                    category: category,
                    priority: priority,
                  ),
                  if (_actionError != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: _actionError!),
                  ],
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Message',
                    icon: Icons.mail_outline_rounded,
                    child: SelectableText(
                      body.isEmpty ? 'No plain-text body available.' : body,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.email.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AttachmentsCard(attachments: widget.email.attachments),
                  ],
                  if (widget.email.analysis != null) ...[
                    const SizedBox(height: 12),
                    _AnalysisCard(analysis: widget.email.analysis!),
                  ],
                  if (widget.email.jury != null) ...[
                    const SizedBox(height: 12),
                    _JuryCard(jury: widget.email.jury!),
                  ],
                  if (_isEditMode || _hasSuggestedReply(widget.email)) ...[
                    const SizedBox(height: 12),
                    _ReplyCard(
                      controller: _replyController,
                      editable: _isEditMode,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasSuggestedReply(Email email) {
    return email.analysis?.suggestedReply.trim().isNotEmpty == true;
  }
}

class _DetailTone {
  const _DetailTone({
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

  static _DetailTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _DetailTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
      softSurface:
          isDark
              ? AppPalette.white.withValues(alpha: 0.07)
              : AppPalette.sage.withValues(alpha: 0.58),
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

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.title,
    required this.status,
    required this.onBack,
  });

  final String title;
  final Status status;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: tone.text,
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: tone.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _InfoPill(label: _statusLabel(status), color: statusColor),
        ],
      ),
    );
  }
}

class _MessageHero extends StatelessWidget {
  const _MessageHero({
    required this.email,
    required this.category,
    required this.priority,
  });

  final Email email;
  final EmailCategory category;
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final senderName = _senderName(email.from);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SenderAvatar(sender: email.from),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _senderAddress(email.from),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDate(email.date),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            email.subject.trim().isEmpty ? '(No subject)' : email.subject,
            style: TextStyle(
              color: tone.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: _priorityLabel(priority),
                color: _priorityColor(priority),
              ),
              _InfoPill(
                label: _categoryLabel(category),
                color: _categoryColor(category),
              ),
              if (email.attachments.isNotEmpty)
                _InfoPill(
                  label:
                      '${email.attachments.length} attachment${email.attachments.length == 1 ? '' : 's'}',
                  color: AppPalette.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender});

  final Sender sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 21,
      backgroundColor: AppPalette.teal.withValues(alpha: 0.14),
      child: Text(
        _initial(sender),
        style: const TextStyle(
          color: AppPalette.deepTeal,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final color = accent ?? AppPalette.deepTeal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final priority = analysis.priority;
    final category = analysis.category ?? EmailCategory.INFORMATION;

    return _SectionCard(
      title: 'Assistant analysis',
      icon: Icons.auto_awesome_rounded,
      accent: AppPalette.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: _categoryLabel(category),
                color: _categoryColor(category),
              ),
              _InfoPill(
                label: _priorityLabel(priority),
                color: _priorityColor(priority),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis.summary.trim().isEmpty
                ? 'No summary available.'
                : analysis.summary,
            style: TextStyle(
              color: tone.text,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _JuryCard extends StatelessWidget {
  const _JuryCard({required this.jury});

  final Jury jury;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);
    final color = _verdictColor(jury.verdict);
    final reasoning = jury.reasoning?.trim();

    return _SectionCard(
      title: 'Final check',
      icon: Icons.verified_outlined,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPill(label: _verdictLabel(jury.verdict), color: color),
          if (reasoning != null && reasoning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reasoning,
              style: TextStyle(
                color: tone.text,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.controller, required this.editable});

  final TextEditingController controller;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);

    return _SectionCard(
      title: editable ? 'Suggested reply' : 'Reply draft',
      icon: Icons.edit_note_rounded,
      accent: AppPalette.deepTeal,
      child:
          editable
              ? TextField(
                controller: controller,
                minLines: 6,
                maxLines: 12,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Edit the reply before sending...',
                  hintStyle: TextStyle(color: tone.muted),
                  filled: true,
                  fillColor: tone.softSurface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: tone.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: tone.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.teal),
                  ),
                ),
              )
              : SelectableText(
                controller.text,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({required this.attachments});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);

    return _SectionCard(
      title: 'Attachments',
      icon: Icons.attach_file_rounded,
      accent: AppPalette.amber,
      child: Column(
        children:
            attachments.map((attachment) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tone.softSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tone.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      color: AppPalette.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tone.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatFileSize(attachment.size),
                            style: TextStyle(
                              color: tone.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isSubmitting,
    required this.onSend,
    required this.onEditSend,
    required this.onSkip,
  });

  final bool isSubmitting;
  final VoidCallback onSend;
  final VoidCallback onEditSend;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tone = _DetailTone.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: tone.surface,
          border: Border(top: BorderSide(color: tone.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onSend,
                icon:
                    isSubmitting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onEditSend,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit & send'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppPalette.lavender
                          : AppPalette.deepTeal,
                  side: BorderSide(
                    color: AppPalette.deepTeal.withValues(alpha: 0.34),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Skip reply',
              child: IconButton(
                onPressed: isSubmitting ? null : onSkip,
                style: IconButton.styleFrom(
                  backgroundColor: AppPalette.clay.withValues(alpha: 0.10),
                  foregroundColor: AppPalette.clay,
                  disabledForegroundColor: tone.muted.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.clay.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.clay.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppPalette.clay,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppPalette.clay,
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

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
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

String _senderName(Sender sender) {
  final name = sender.name.trim();
  if (name.isNotEmpty) return name;
  final email = sender.email.trim();
  return email.isEmpty ? 'Unknown sender' : email;
}

String _senderAddress(Sender sender) {
  final email = sender.email.trim();
  return email.isEmpty ? 'No sender address' : email;
}

String _initial(Sender sender) {
  final source = sender.name.trim().isNotEmpty ? sender.name : sender.email;
  final trimmed = source.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

String _formatDate(DateTime date) {
  return '${date.day} ${_monthName(date.month)} ${date.year}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _monthName(int month) {
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
  return months[month - 1];
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _statusLabel(Status status) {
  switch (status) {
    case Status.DONE:
      return 'SENT';
    case Status.PENDING_USER_REVIEW:
      return 'REVIEW';
    case Status.PENDING_JURY:
      return 'CHECKING';
    case Status.PENDING_ANALYSIS:
      return 'DRAFTING';
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
    case EmailCategory.INFORMATION:
      return 'INFO';
    case EmailCategory.SUPPORT:
      return 'SUPPORT';
    case EmailCategory.COMMERCIAL:
      return 'COMMERCIAL';
  }
}

Color _categoryColor(EmailCategory category) {
  switch (category) {
    case EmailCategory.RECLAMATION:
      return AppPalette.clay;
    case EmailCategory.INFORMATION:
      return AppPalette.blue;
    case EmailCategory.SUPPORT:
      return AppPalette.amber;
    case EmailCategory.COMMERCIAL:
      return AppPalette.deepTeal;
  }
}

String _verdictLabel(JuryVerdict verdict) {
  switch (verdict) {
    case JuryVerdict.APPROVED:
      return 'VALIDATED';
    case JuryVerdict.REJECTED:
      return 'REJECTED';
    case JuryVerdict.UNCERTAIN:
      return 'NEEDS CHECK';
  }
}

Color _verdictColor(JuryVerdict verdict) {
  switch (verdict) {
    case JuryVerdict.APPROVED:
      return AppPalette.teal;
    case JuryVerdict.REJECTED:
      return AppPalette.clay;
    case JuryVerdict.UNCERTAIN:
      return AppPalette.amber;
  }
}
