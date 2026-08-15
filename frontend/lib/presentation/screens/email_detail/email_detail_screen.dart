import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';

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
  late final TextEditingController _replyController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(
      text:
          widget.email.analysis?.suggestedReply.trim().isNotEmpty == true
              ? widget.email.analysis!.suggestedReply
              : widget.email.body.plain.trim().isNotEmpty
              ? widget.email.body.plain
              : 'Hi,\n\nThanks for your message. We are reviewing it and will come back to you shortly.\n\nBest regards,',
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

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

  String _getVerdictLabel(JuryVerdict verdict) {
    switch (verdict) {
      case JuryVerdict.APPROVED:
        return 'Validated';
      case JuryVerdict.REJECTED:
        return 'Rejected';
      case JuryVerdict.UNCERTAIN:
        return 'Uncertain';
    }
  }

  Color _getVerdictColor(JuryVerdict verdict) {
    switch (verdict) {
      case JuryVerdict.APPROVED:
        return Colors.green;
      case JuryVerdict.REJECTED:
        return Colors.red;
      case JuryVerdict.UNCERTAIN:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  Future<void> _confirmAndSend(String actionLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirm send'),
            content: Text('Send this reply as $actionLabel?'),
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

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply sent: $actionLabel'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _ignoreEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ignore message'),
            content: const Text(
              'Do you want to ignore this email without sending a reply?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ignore'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = widget.email.analysis?.priority ?? Priority.NORMAL;
    final category = widget.email.analysis?.category;
    final analysis = widget.email.analysis;
    final jury = widget.email.jury;

    if (widget.mode == EmailDetailMode.edit) {
      return _buildEditMode(context, priority, category, analysis, jury);
    }

    return _buildReadOnlyMode(context, priority, category, analysis, jury);
  }

  Widget _buildEditMode(
    BuildContext context,
    Priority priority,
    EmailCategory? category,
    Analysis? analysis,
    Jury? jury,
  ) {
    final verdict = jury?.verdict ?? JuryVerdict.UNCERTAIN;
    final confidence =
        analysis != null
            ? '${(analysis.confidence * 100).toStringAsFixed(0)}%'
            : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Review & respond',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getPriorityColor(priority).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getPriorityLabel(priority),
              style: TextStyle(
                color: _getPriorityColor(priority),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.email.subject.trim().isEmpty
                    ? '(No subject)'
                    : widget.email.subject,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email.from.email,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  widget.email.body.plain.trim().isEmpty
                      ? 'No plain-text body available.'
                      : widget.email.body.plain,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'AI-SUGGESTED REPLY — EDITABLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _replyController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Edit your response…',
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'JURY VERDICT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Verdict',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getVerdictColor(
                              verdict,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getVerdictLabel(verdict),
                            style: TextStyle(
                              color: _getVerdictColor(verdict),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confidence',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          confidence,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (jury?.reasoning != null &&
                        jury!.reasoning!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Reason',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jury.reasoning!,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirmAndSend('as-is'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Send as-is'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirmAndSend('edited response'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.lavender,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Edit & send'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ignoreEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Ignore'),
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

  Widget _buildReadOnlyMode(
    BuildContext context,
    Priority priority,
    EmailCategory? category,
    Analysis? analysis,
    Jury? jury,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Detail'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EmailHeader(
              subject: widget.email.subject,
              senderName: widget.email.from.name,
              senderEmail: widget.email.from.email,
              date: _formatDate(widget.email.date),
              category: category,
              priority: priority,
              categoryColor: _getCategoryColor(category),
              priorityColor: _getPriorityColor(priority),
            ),
            const SizedBox(height: 24),
            _ContentSection(
              title: 'Email Content',
              content:
                  widget.email.body.plain.trim().isEmpty
                      ? 'No plain-text body available.'
                      : widget.email.body.plain,
            ),
            const SizedBox(height: 24),
            if (widget.email.attachments.isNotEmpty) ...[
              _AttachmentsSection(attachments: widget.email.attachments),
              const SizedBox(height: 24),
            ],
            if (analysis != null) ...[
              _AnalysisSection(
                category: _getCategoryLabel(analysis.category),
                categoryColor: _getCategoryColor(analysis.category),
                priority: _getPriorityLabel(priority),
                priorityColor: _getPriorityColor(priority),
                confidence:
                    '${(analysis.confidence * 100).toStringAsFixed(0)}%',
                summary: analysis.summary,
              ),
              const SizedBox(height: 24),
            ],
            if (jury != null) ...[
              _VerdictSection(
                verdict: _getVerdictLabel(jury.verdict),
                verdictColor: _getVerdictColor(jury.verdict),
                reasoning: jury.reasoning,
              ),
              const SizedBox(height: 24),
            ],
            if (analysis != null &&
                analysis.suggestedReply.trim().isNotEmpty) ...[
              _SuggestedReplySection(suggestedReply: analysis.suggestedReply),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmailHeader extends StatelessWidget {
  const _EmailHeader({
    required this.subject,
    required this.senderName,
    required this.senderEmail,
    required this.date,
    required this.category,
    required this.priority,
    required this.categoryColor,
    required this.priorityColor,
  });

  final String subject;
  final String senderName;
  final String senderEmail;
  final String date;
  final EmailCategory? category;
  final Priority priority;
  final Color categoryColor;
  final Color priorityColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject + Badges
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                subject.trim().isEmpty ? '(No subject)' : subject,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryLabel(category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priority.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sender Info
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppPalette.lavender.withValues(alpha: 0.2),
              child: Text(
                _initial(senderName, senderEmail),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.lavender,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName.trim().isEmpty ? 'Unknown sender' : senderName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    senderEmail.trim().isEmpty
                        ? 'No sender address'
                        : senderEmail,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Date
        Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  String _initial(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    return source.isEmpty ? '?' : source[0].toUpperCase();
  }

  String _categoryLabel(EmailCategory? category) {
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
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments});

  final List<Attachment> attachments;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments (${attachments.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...attachments.map((attachment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.filename,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(attachment.size),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.download, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({
    required this.category,
    required this.categoryColor,
    required this.priority,
    required this.priorityColor,
    required this.confidence,
    required this.summary,
  });

  final String category;
  final Color categoryColor;
  final String priority;
  final Color priorityColor;
  final String confidence;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGENT ANALYSIS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnalysisRow(
                label: 'Category',
                value: category,
                color: categoryColor,
              ),
              const SizedBox(height: 12),
              _AnalysisRow(
                label: 'Priority',
                value: priority,
                color: priorityColor,
              ),
              const SizedBox(height: 12),
              _AnalysisRow(
                label: 'Confidence',
                value: confidence,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary.trim().isEmpty ? 'No summary available.' : summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerdictSection extends StatelessWidget {
  const _VerdictSection({
    required this.verdict,
    required this.verdictColor,
    required this.reasoning,
  });

  final String verdict;
  final Color verdictColor;
  final String? reasoning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JURY VERDICT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: verdictColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: verdictColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verdict',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: verdictColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: verdictColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (reasoning != null && reasoning!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reasoning',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reasoning!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestedReplySection extends StatelessWidget {
  const _SuggestedReplySection({required this.suggestedReply});

  final String suggestedReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUGGESTED REPLY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Draft prepared by the agent',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                suggestedReply,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
