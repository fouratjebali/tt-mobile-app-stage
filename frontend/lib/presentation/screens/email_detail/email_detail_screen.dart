import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';

class EmailDetailScreen extends StatelessWidget {
  const EmailDetailScreen({
    super.key,
    required this.email,
  });

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
      'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final priority = email.analysis?.priority ?? Priority.NORMAL;
    final category = email.analysis?.category;
    final analysis = email.analysis;
    final jury = email.jury;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Detail'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // EMAIL HEADER SECTION
            _EmailHeader(
              subject: email.subject,
              senderName: email.from.name,
              senderEmail: email.from.email,
              date: _formatDate(email.date),
              category: category,
              priority: priority,
              categoryColor: _getCategoryColor(category),
              priorityColor: _getPriorityColor(priority),
            ),
            const SizedBox(height: 24),

            // EMAIL BODY SECTION
            _ContentSection(
              title: 'Email Content',
              content: email.body.plain,
            ),
            const SizedBox(height: 24),

            // ATTACHMENTS SECTION
            if (email.attachments.isNotEmpty) ...[
              _AttachmentsSection(attachments: email.attachments),
              const SizedBox(height: 24),
            ],

            // AGENT IA 1 - ANALYSIS SECTION
            if (analysis != null) ...[
              _AnalysisSection(
                category: _getCategoryLabel(analysis.category),
                categoryColor: _getCategoryColor(analysis.category),
                priority: _getPriorityLabel(priority),
                priorityColor: _getPriorityColor(priority),
                urgencyScore: '5 / 10',
                confidence: '${(analysis.confidence * 100).toStringAsFixed(0)}%',
                summary: analysis.summary,
              ),
              const SizedBox(height: 24),
            ],

            // JURY AGENT 2 - VERDICT SECTION
            if (jury != null) ...[
              _VerdictSection(
                verdict: _getVerdictLabel(jury.verdict),
                verdictColor: _getVerdictColor(jury.verdict),
                confidence: jury.reasoning ?? '88%',
                reasoning: jury.reasoning,
              ),
              const SizedBox(height: 24),
            ],

            // REPLY SENT AUTOMATICALLY SECTION
            if (analysis != null) ...[
              _ReplySentSection(
                suggestedReply: analysis.suggestedReply,
              ),
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
                subject,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category?.name ?? 'INFO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                senderName[0].toUpperCase(),
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
                    senderName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    senderEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Date
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.title,
    required this.content,
  });

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
            borderRadius: BorderRadius.circular(12),
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
                  Icon(
                    Icons.attach_file,
                    color: Colors.grey[600],
                    size: 20,
                  ),
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
        }).toList(),
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
    required this.urgencyScore,
    required this.confidence,
    required this.summary,
  });

  final String category;
  final Color categoryColor;
  final String priority;
  final Color priorityColor;
  final String urgencyScore;
  final String confidence;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGENT IA 1 -- ANALYSIS',
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
            borderRadius: BorderRadius.circular(12),
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
                label: 'Urgency score',
                value: urgencyScore,
                color: Colors.orange,
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
                summary,
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
    required this.confidence,
    required this.reasoning,
  });

  final String verdict;
  final Color verdictColor;
  final String confidence;
  final String? reasoning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JURY AGENT 2 -- VERDICT',
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
            borderRadius: BorderRadius.circular(12),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    confidence,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
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

class _ReplySentSection extends StatelessWidget {
  const _ReplySentSection({required this.suggestedReply});

  final String suggestedReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPLY SENT AUTOMATICALLY',
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reply sent successfully',
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
