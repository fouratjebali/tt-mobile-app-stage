import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:tt_mail_assistant/data/repositories/email_repository_impl.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';


class MockApiService extends Mock implements ApiService {}

class MockEmailLocalDataSource extends Mock
    implements EmailLocalDataSource {}


void main() {

  late EmailRepositoryImpl repository;
  late MockApiService apiService;
  late MockEmailLocalDataSource localDataSource;


  setUp(() {
    apiService = MockApiService();
    localDataSource = MockEmailLocalDataSource();

    repository = EmailRepositoryImpl(
      apiService: apiService,
      localDataSource: localDataSource,
    );
  });



  test(
    'getTodayEmails returns API emails and saves cache',
        () async {

      final response = {
        "emails": [
          {
            "id": "1",
            "subject": "Test mail",
            "date": DateTime.now().toIso8601String(),
            "from": {
              "name": "Senda",
              "email": "senda@test.com"
            },
          }
        ]
      };


      when(apiService.get('/email/today'))
          .thenAnswer((_) async => response);



      final result =
      await repository.getTodayEmails();



      expect(result.length, 1);
      expect(result.first.subject, "Test mail");


      verify(
          localDataSource.saveEmails(any)
      ).called(1);

    },
  );



  test(
    'getTodayEmails uses cache when API fails',
        () async {


      when(apiService.get('/email/today'))
          .thenThrow(Exception());


      when(localDataSource.getTodayEmails())
          .thenAnswer(
            (_) async => [],
      );


      final result =
      await repository.getTodayEmails();


      expect(result, isEmpty);


      verify(
          localDataSource.getTodayEmails()
      ).called(1);

    },
  );



  test(
    'getEmailById returns email from API',
        () async {


      when(apiService.get('/email/1'))
          .thenAnswer(
            (_) async => {
          "id":"1",
          "subject":"Hello",
          "date":DateTime.now().toIso8601String()
        },
      );


      final result =
      await repository.getEmailById("1");


      expect(result, isNotNull);
      expect(result!.id, "1");


      verify(
          localDataSource.saveEmail(any)
      ).called(1);

    },
  );



  test(
    'getEmailById uses cache when API fails',
        () async {


      when(apiService.get('/email/1'))
          .thenThrow(Exception());


      when(localDataSource.getEmailById("1"))
          .thenAnswer(
            (_) async => null,
      );


      final result =
      await repository.getEmailById("1");


      expect(result, null);


      verify(
          localDataSource.getEmailById("1")
      ).called(1);

    },
  );



  test(
    'markAsRead calls local datasource',
        () async {


      await repository.markAsRead("1");


      verify(
          localDataSource.markAsRead("1")
      ).called(1);

    },
  );

}