import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/repositories/email_repository.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';

class EmailRepositoryImpl implements EmailRepository {
  EmailRepositoryImpl({
    required this.apiService,
    required this.localDataSource,
  });

  final ApiService apiService;
  final EmailLocalDataSource localDataSource;

  @override
  Future<List<Email>> getEmails() => getTodayEmails();

  @override
  Future<Email> getEmailDetails({required String emailId}) async {
    final email = await getEmailById(emailId);
    if (email == null) {
      throw ApiException(statusCode: 404, message: 'Email not found.');
    }
    return email;
  }

  @override
  Future<void> sendReply({required String emailId, required String body}) =>
      validateAndSend(emailId: emailId, body: body);

  @override
  Future<void> validateAndSend({
    required String emailId,
    required String body,
  }) async {
    await apiService.post('/email/$emailId/send', body: {'body': body});
  }

  @override
  Future<void> editAndSend({required String emailId, required String body}) =>
      validateAndSend(emailId: emailId, body: body);

  @override
  Future<void> reject({required String emailId}) async {
    await apiService.post('/email/$emailId/reject');
  }

  @override
  Future<List<Email>> getTodayEmails() async {
    try {
      final payload = await apiService.get('/email/today');

      final emails = _parseEmailList(payload);

      await localDataSource.saveEmails(emails);

      return emails;
    } catch (_) {
      return await localDataSource.getTodayEmails();
    }
  }

  @override
  Future<List<Email>> getReviewRequiredEmails() async {
    try {
      final payload = await apiService.get('/email/review');

      final emails = _parseEmailList(payload);

      await localDataSource.saveEmails(emails);

      return emails;
    } catch (_) {
      return await localDataSource.getReviewEmails();
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardStats({required String period}) async {
    final payload = await apiService.get('/dashboard/stats', queryParameters: {
      'period': period,
    });
    return _asMap(payload);
  }

  @override
  Future<Map<String, dynamic>> exportDashboardReport({required String period}) async {
    final payload = await apiService.post('/dashboard/export', body: {
      'period': period,
    });
    return _asMap(payload);
  }

  @override
  Future<Email?> getEmailById(String id) async {
    try {
      final payload = await apiService.get('/email/$id');

      final map = _asMap(payload);
      if (map.isEmpty) return null;

      Email email;

      final emailPayload = map['email'];

      if (emailPayload is Map) {
        email = _parseEmail({
          ..._asMap(emailPayload),
          if (map.containsKey('analysis')) 'analysis': map['analysis'],
          if (map.containsKey('jury')) 'jury': map['jury'],
          if (map.containsKey('jury_verdict'))
            'jury_verdict': map['jury_verdict'],
        });
      } else {
        email = _parseEmail(map);
      }

      await localDataSource.saveEmail(email);

      return email;
    } catch (_) {
      return await localDataSource.getEmailById(id);
    }
  }

  List<Email> _parseEmailList(Object? payload) {
    return _extractList(payload)
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .map(_parseEmail)
        .toList(growable: false);
  }

  List<Object?> _extractList(Object? payload) {
    if (payload is List) return payload;

    final map = _asMap(payload);
    for (final key in ['emails', 'items', 'results']) {
      final value = map[key];
      if (value is List) return value;
    }

    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final dataMap = _asMap(data);
      for (final key in ['emails', 'items', 'results']) {
        final value = dataMap[key];
        if (value is List) return value;
      }
    }

    return const [];
  }

  Email _parseEmail(Map<String, dynamic> json) {
    final id = _string(json['id'] ?? json['email_id'] ?? json['gmail_id']);

    return Email(
      id: id.isEmpty ? 'unknown' : id,
      threadId: _string(json['thread_id'] ?? json['threadId']),
      subject: _string(json['subject'], fallback: '(No subject)'),
      from: _parseSender(json['from'] ?? json['sender']),
      to: _parseRecipients(json['to'] ?? json['recipients']),
      date: _parseDate(json['date'] ?? json['received_at']),
      body: _parseBody(json['body'] ?? json['body_text'] ?? json['preview']),
      attachments: _parseAttachments(json['attachments']),
      status: _parseStatus(json['status']),
      analysis: _parseAnalysis(json['analysis']),
      jury: _parseJury(json['jury'] ?? json['jury_verdict']),
    );
  }

  Sender _parseSender(Object? value) {
    if (value is Map) {
      final map = _asMap(value);
      return Sender(
        name: _string(map['name'] ?? map['display_name']),
        email: _string(map['email'] ?? map['address']),
      );
    }

    final email = _string(value);
    return Sender(name: email, email: email);
  }

  List<Sender> _parseRecipients(Object? value) {
    if (value is List) return value.map(_parseSender).toList(growable: false);

    final raw = _string(value);
    if (raw.isEmpty) return const [];

    return raw
        .split(',')
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .map((email) => Sender(name: email, email: email))
        .toList(growable: false);
  }

  EmailBody _parseBody(Object? value) {
    if (value is Map) {
      final map = _asMap(value);
      return EmailBody(
        plain: _string(map['plain'] ?? map['text']),
        html: _string(map['html']),
      );
    }

    return EmailBody(plain: _string(value), html: '');
  }

  List<Attachment> _parseAttachments(Object? value) {
    if (value is! List) return const [];

    return value
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .map((item) {
          return Attachment(
            id: _string(item['id']),
            filename: _string(item['filename'] ?? item['name']),
            mimeType: _string(item['mime_type'] ?? item['mimeType']),
            size: _int(item['size']),
          );
        })
        .toList(growable: false);
  }

  Analysis? _parseAnalysis(Object? value) {
    if (value is! Map) return null;
    final map = _asMap(value);

    return Analysis(
      summary: _string(map['summary']),
      suggestedReply: _string(map['suggested_reply'] ?? map['suggestedReply']),
      priority: _parsePriority(map['priority']),
      confidence: _double(map['confidence'] ?? map['confidence_score']),
      category: _parseCategory(map['category']),
    );
  }

  Jury? _parseJury(Object? value) {
    if (value is! Map) return null;
    final map = _asMap(value);

    return Jury(
      verdict: _parseVerdict(map['verdict']),
      reasoning: _string(map['reasoning'] ?? map['comment']),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  DateTime _parseDate(Object? value) {
    return DateTime.tryParse(_string(value)) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Priority _parsePriority(Object? value) {
    final normalized = _string(value).toUpperCase();
    return Priority.values.firstWhere(
      (priority) => priority.name == normalized,
      orElse: () => Priority.NORMAL,
    );
  }

  EmailCategory? _parseCategory(Object? value) {
    final normalized = _string(value).toUpperCase();
    if (normalized.isEmpty) return null;

    return EmailCategory.values.firstWhere(
      (category) => category.name == normalized,
      orElse: () => EmailCategory.INFORMATION,
    );
  }

  Status _parseStatus(Object? value) {
    final normalized = _string(value).toUpperCase();
    return Status.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => Status.PENDING_ANALYSIS,
    );
  }

  JuryVerdict _parseVerdict(Object? value) {
    final normalized = _string(value).toUpperCase();
    return JuryVerdict.values.firstWhere(
      (verdict) => verdict.name == normalized || normalized == 'VALIDATED',
      orElse: () => JuryVerdict.UNCERTAIN,
    );
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(_string(value)) ?? 0;
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_string(value)) ?? 0;
  }

  @override
  Future<void> markAsRead(String id) async {
    await localDataSource.markAsRead(id);
  }
}
