import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tt_mail_assistant/core/config/api_config.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
<<<<<<< HEAD
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service_impl.dart';
=======
import 'package:tt_mail_assistant/data/datasources/remote/agent_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/jury_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/sentiment_remote_data_source.dart';
import 'package:tt_mail_assistant/data/repositories/agent_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/auth_repository_impl.dart';
<<<<<<< HEAD
import 'package:tt_mail_assistant/data/repositories/email_repository_impl.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/email_repository.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tt_mail_assistant/data/repositories/settings_repository_impl.dart';
import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/data/datasources/local/database_helper.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource_impl.dart';
/// Dtool: get_it (already in pubspec.yaml, chosen as the service locator
/// for this project — see the "Choisir l'outil DI" subtask).
=======
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

>>>>>>> origin/sprint-4-backend-api-mobile-foundations
final getIt = GetIt.instance;

Future<void> init() async {
  if (getIt.isRegistered<AuthUseCase>()) return;

  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<ThemeController>(
    ThemeController(getIt<SharedPreferences>()),
  );

  // ---------------------------------------------------------------------
  // DataSources
  // ---------------------------------------------------------------------
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
<<<<<<< HEAD
    BackendAuthDataSource.new,
  );
  getIt.registerLazySingleton<ApiService>(
        () => ApiServiceImpl(baseUrl: ApiConfig.baseUrl),
  );
  getIt.registerLazySingleton<DatabaseHelper>(
        () => DatabaseHelper.instance,
  );

  getIt.registerLazySingleton<EmailLocalDataSource>(
        () => EmailLocalDataSourceImpl(
      databaseHelper: getIt<DatabaseHelper>(),
    ),
  );
  // ---------------------------------------------------------------------
  // Repositories

  // ---------------------------------------------------------------------
=======
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
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
  getIt.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(
      secureStorage: getIt<AuthSecureStorage>(),
      googleAuthDataSource: getIt<GoogleAuthDataSource>(),
      backendAuthDataSource: getIt<BackendAuthDataSource>(),
    ),
  );
  getIt.registerLazySingleton<EmailRepository>(
        () => EmailRepositoryImpl(
      apiService: getIt<ApiService>(),
      localDataSource: getIt<EmailLocalDataSource>(),
    ),
  );
<<<<<<< HEAD
  getIt.registerLazySingleton<SettingsRepository>(
        () => SettingsRepositoryImpl(
      getIt<SharedPreferences>(),
    ),
  );

  // ---------------------------------------------------------------------
  // UseCases
  // ---------------------------------------------------------------------
  getIt.registerLazySingleton<AuthUseCase>(
        () => AuthUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<EmailUseCase>(
        () => EmailUseCase(getIt<EmailRepository>()),
  );
}
=======
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
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
