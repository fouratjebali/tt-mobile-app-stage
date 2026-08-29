import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:tt_mail_assistant/data/datasources/local/database_helper.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';

class EmailLocalDataSourceImpl implements EmailLocalDataSource {
  final DatabaseHelper databaseHelper;

  EmailLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> saveEmails(List<Email> emails) async {
    for (final email in emails) {
      await saveEmail(email);
    }
  }

  @override
  Future<void> saveEmail(Email email) async {
    final db = await databaseHelper.database;

    await db.insert('emails', {
      'id': email.id,
      'threadId': email.threadId,
      'subject': email.subject,
      'sender': email.from.name,
      'senderEmail': email.from.email,
      'recipients': jsonEncode(
        email.to.map((e) => {'name': e.name, 'email': e.email}).toList(),
      ),
      'body': email.body.plain,
      'date': email.date.toIso8601String(),
      'status': email.status.name,
      'attachments': jsonEncode(
        email.attachments
            .map(
              (a) => {
                'id': a.id,
                'filename': a.filename,
                'mimeType': a.mimeType,
                'size': a.size,
              },
            )
            .toList(),
      ),
      'analysis':
          email.analysis == null
              ? null
              : jsonEncode({
                'summary': email.analysis!.summary,
                'suggestedReply': email.analysis!.suggestedReply,
                'priority': email.analysis!.priority.name,
                'confidence': email.analysis!.confidence,
                'category': email.analysis!.category?.name,
              }),
      'jury':
          email.jury == null
              ? null
              : jsonEncode({
                'verdict': email.jury!.verdict.name,
                'reasoning': email.jury!.reasoning,
              }),
      'isRead': email.status == Status.DONE ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Email>> getEmails() async {
    final db = await databaseHelper.database;

    final result = await db.query('emails');

    return result.map(_mapToEmail).toList();
  }

  @override
  Future<List<Email>> getTodayEmails() async {
    final emails = await getEmails();

    final now = DateTime.now();

    return emails.where((email) {
      return email.date.year == now.year &&
          email.date.month == now.month &&
          email.date.day == now.day;
    }).toList();
  }

  @override
  Future<List<Email>> getReviewEmails() async {
    final emails = await getEmails();

    return emails
        .where((email) => email.status == Status.PENDING_USER_REVIEW)
        .toList();
  }

  @override
  Future<Email?> getEmailById(String id) async {
    final db = await databaseHelper.database;

    final result = await db.query('emails', where: 'id = ?', whereArgs: [id]);

    if (result.isEmpty) {
      return null;
    }

    return _mapToEmail(result.first);
  }

  @override
  Future<void> markAsRead(String id) async {
    final db = await databaseHelper.database;

    await db.update('emails', {'isRead': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Email _mapToEmail(Map<String, dynamic> map) {
    final recipients =
        (jsonDecode(map['recipients'] ?? '[]') as List)
            .map(
              (e) => Sender(
                name: e['name'] as String,
                email: e['email'] as String,
              ),
            )
            .toList();

    final attachments =
        (jsonDecode(map['attachments'] ?? '[]') as List)
            .map(
              (e) => Attachment(
                id: e['id'] as String,
                filename: e['filename'] as String,
                mimeType: e['mimeType'] as String,
                size: (e['size'] as num).toInt(),
              ),
            )
            .toList();

    Analysis? analysis;

    if (map['analysis'] != null) {
      final a = jsonDecode(map['analysis']);

      analysis = Analysis(
        summary: a['summary'] ?? '',
        suggestedReply: a['suggestedReply'] ?? '',
        priority: Priority.values.firstWhere(
          (p) => p.name == a['priority'],
          orElse: () => Priority.NORMAL,
        ),
        confidence: (a['confidence'] as num?)?.toDouble() ?? 0,
        category:
            a['category'] == null
                ? null
                : EmailCategory.values.firstWhere(
                  (c) => c.name == a['category'],
                  orElse: () => EmailCategory.INFORMATION,
                ),
      );
    }

    Jury? jury;

    if (map['jury'] != null) {
      final j = jsonDecode(map['jury']);

      jury = Jury(
        verdict: JuryVerdict.values.firstWhere(
          (v) => v.name == j['verdict'],
          orElse: () => JuryVerdict.UNCERTAIN,
        ),
        reasoning: j['reasoning'],
      );
    }

    return Email(
      id: map['id'] as String,
      threadId: map['threadId'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      from: Sender(
        name: map['sender'] as String? ?? '',
        email: map['senderEmail'] as String? ?? '',
      ),
      to: recipients,
      date:
          DateTime.tryParse(map['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      body: EmailBody(plain: map['body'] as String? ?? '', html: ''),
      attachments: attachments,
      status: Status.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => Status.PENDING_ANALYSIS,
      ),
      analysis: analysis,
      jury: jury,
    );
  }
}
