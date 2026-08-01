import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/remote/agent_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/jury_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/sentiment_remote_data_source.dart';
import 'package:tt_mail_assistant/data/repositories/agent_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/auth_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/jury_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/sentiment_repository_impl.dart';
import 'package:tt_mail_assistant/domain/repositories/agent_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/jury_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/sentiment_repository.dart';
import 'package:tt_mail_assistant/domain/usecases/agent_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/jury_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/sentiment_usecase.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  if (getIt.isRegistered<AuthUseCase>()) return;

  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<AuthSecureStorage>(
    () => AuthSecureStorage(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(secureStorage: getIt<AuthSecureStorage>()),
  );
  getIt.registerLazySingleton<GoogleAuthDataSource>(GoogleAuthDataSource.new);
  getIt.registerLazySingleton<BackendAuthDataSource>(
    () => BackendAuthDataSource(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<AgentRemoteDataSource>(
    () => AgentRemoteDataSource(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<JuryRemoteDataSource>(
    () => JuryRemoteDataSource(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<SentimentRemoteDataSource>(
    () => SentimentRemoteDataSource(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      secureStorage: getIt<AuthSecureStorage>(),
      googleAuthDataSource: getIt<GoogleAuthDataSource>(),
      backendAuthDataSource: getIt<BackendAuthDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AuthUseCase>(
    () => AuthUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<AgentRepository>(
    () => AgentRepositoryImpl(getIt<AgentRemoteDataSource>()),
  );
  getIt.registerLazySingleton<JuryRepository>(
    () => JuryRepositoryImpl(getIt<JuryRemoteDataSource>()),
  );
  getIt.registerLazySingleton<SentimentRepository>(
    () => SentimentRepositoryImpl(getIt<SentimentRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AgentUseCase>(
    () => AgentUseCase(getIt<AgentRepository>()),
  );
  getIt.registerLazySingleton<JuryUseCase>(
    () => JuryUseCase(getIt<JuryRepository>()),
  );
  getIt.registerLazySingleton<SentimentUseCase>(
    () => SentimentUseCase(getIt<SentimentRepository>()),
  );
}
