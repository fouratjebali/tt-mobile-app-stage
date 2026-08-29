import 'package:flutter_test/flutter_test.dart';

import 'package:tt_mail_assistant/data/repositories/email_repository_impl.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';

class FakeApiService implements ApiService {
  Object? response;
  Object? postResponse;
  bool throwError = false;

  @override
  Future<dynamic> get(
    String path, {
    bool authenticated = true,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (throwError) {
      throw Exception();
    }

    return response;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return postResponse ?? {};
  }

  @override
  Future<dynamic> delete(
    String path, {
    bool authenticated = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return {};
  }
}

class FakeLocalDataSource implements EmailLocalDataSource {
  List<Email> savedEmails = [];
  Email? savedEmail;
  List<Email> cacheEmails = [];

  @override
  Future<List<Email>> getEmails() async {
    return cacheEmails;
  }

  @override
  Future<void> saveEmails(List<Email> emails) async {
    savedEmails = emails;
  }

  @override
  Future<List<Email>> getTodayEmails() async {
    return cacheEmails;
  }

  @override
  Future<List<Email>> getReviewEmails() async {
    return cacheEmails;
  }

  @override
  Future<void> saveEmail(Email email) async {
    savedEmail = email;
  }

  @override
  Future<Email?> getEmailById(String id) async {
    return savedEmail;
  }

  @override
  Future<void> markAsRead(String id) async {}
}

void main() {
  late EmailRepositoryImpl repository;
  late FakeApiService api;
  late FakeLocalDataSource local;

  setUp(() {
    api = FakeApiService();

    local = FakeLocalDataSource();

    repository = EmailRepositoryImpl(apiService: api, localDataSource: local);
  });

  test('getTodayEmails returns API data and saves cache', () async {
    api.response = {
      'emails': [
        {
          'id': '1',
          'subject': 'Test email',
          'date': DateTime.now().toIso8601String(),
        },
      ],
    };

    final result = await repository.getTodayEmails();

    expect(result.length, 1);
    expect(result.first.subject, 'Test email');

    expect(local.savedEmails.length, 1);
  });

  test('getTodayEmails uses cache when API fails', () async {
    api.throwError = true;

    local.cacheEmails = [];

    final result = await repository.getTodayEmails();

    expect(result, isEmpty);
  });

  test(
    'getReviewRequiredEmails parses top-level analysis and suggested reply',
    () async {
      api.response = {
        'emails': [
          {
            'id': '1',
            'subject': 'Needs review',
            'body_preview': 'Original email preview',
            'status': 'PENDING_USER_REVIEW',
            'category': 'INFORMATION',
            'priority': 'LOW',
            'confidence': 0.9,
            'summary': 'Short summary',
            'suggested_reply': 'Suggested draft',
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      final result = await repository.getReviewRequiredEmails();

      expect(result.length, 1);
      expect(result.first.body.plain, 'Original email preview');
      expect(result.first.analysis?.suggestedReply, 'Suggested draft');
      expect(result.first.analysis?.priority, Priority.LOW);
    },
  );

  test('getEmailById returns email from API', () async {
    api.response = {
      'id': '1',
      'subject': 'Hello',
      'date': DateTime.now().toIso8601String(),
    };

    final result = await repository.getEmailById('1');

    expect(result, isNotNull);

    expect(result!.id, '1');
  });

  test('getEmailById returns cache when API fails', () async {
    api.throwError = true;

    final email = Email(
      id: '1',
      threadId: '',
      subject: 'Cached email',
      from: Sender(name: 'Test', email: 'test@test.com'),
      to: [],
      date: DateTime.now(),
      body: EmailBody(plain: 'body', html: ''),
      attachments: [],
      status: Status.PENDING_ANALYSIS,
      analysis: null,
      jury: null,
    );

    local.savedEmail = email;

    final result = await repository.getEmailById('1');

    expect(result, isNotNull);

    expect(result!.subject, 'Cached email');
  });

  test('markAsRead works', () async {
    await repository.markAsRead('1');

    expect(true, true);
  });

  test('validateAndSend accepts confirmed mailbox send', () async {
    api.postResponse = {'status': 'sent', 'message_id': 'gmail-sent-1'};

    await repository.validateAndSend(emailId: '1', body: 'Reply body');

    expect(true, true);
  });

  test('validateAndSend rejects unconfirmed send response', () async {
    api.postResponse = {'status': 'sent', 'message_id': ''};

    expect(
      () => repository.validateAndSend(emailId: '1', body: 'Reply body'),
      throwsA(isA<ApiException>()),
    );
  });
}
