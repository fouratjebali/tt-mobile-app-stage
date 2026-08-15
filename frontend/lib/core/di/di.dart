import 'package:tt_mail_assistant/domain/usecases/settings_usecase.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/home_view_model.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/activity_view_model.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tt_mail_assistant/core/config/api_config.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/local/database_helper.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource.dart';
import 'package:tt_mail_assistant/data/datasources/local/email_local_datasource_impl.dart';
import 'package:tt_mail_assistant/data/datasources/remote/agent_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/jury_remote_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/sentiment_remote_data_source.dart';
import 'package:tt_mail_assistant/data/repositories/agent_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/auth_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/email_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/jury_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/sentiment_repository_impl.dart';
import 'package:tt_mail_assistant/data/repositories/settings_repository_impl.dart';
import 'package:tt_mail_assistant/domain/repositories/agent_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/email_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/jury_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/sentiment_repository.dart';
import 'package:tt_mail_assistant/domain/repositories/settings_repository.dart';
import 'package:tt_mail_assistant/domain/usecases/agent_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/jury_usecase.dart';
import 'package:tt_mail_assistant/domain/usecases/sentiment_usecase.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  if (getIt.isRegistered<AuthUseCase>()) return;

  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<ThemeController>(
    ThemeController(getIt<SharedPreferences>()),
  );

  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<AuthSecureStorage>(
    () => AuthSecureStorage(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(
      secureStorage: getIt<AuthSecureStorage>(),
      baseUrl: ApiConfig.baseUrl,
    ),
  );
  getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper.instance);
  getIt.registerLazySingleton<EmailLocalDataSource>(
    () => EmailLocalDataSourceImpl(databaseHelper: getIt<DatabaseHelper>()),
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
  getIt.registerLazySingleton<EmailRepository>(
    () => EmailRepositoryImpl(
      apiService: getIt<ApiService>(),
      localDataSource: getIt<EmailLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<SharedPreferences>()),
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

  getIt.registerLazySingleton<AuthUseCase>(
    () => AuthUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<EmailUseCase>(
    () => EmailUseCase(getIt<EmailRepository>()),
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
  getIt.registerLazySingleton<SettingsUseCase>(
    () => SettingsUseCase(getIt<SettingsRepository>()),
  );
  getIt.registerFactory<HomeViewModel>(
    () => HomeViewModel(
      emailUseCase: getIt<EmailUseCase>(),
      settingsUseCase: getIt<SettingsUseCase>(),
      authUseCase: getIt<AuthUseCase>(),
    ),
  );

  getIt.registerFactory<ActivityViewModel>(
    () => ActivityViewModel(emailUseCase: getIt<EmailUseCase>()),
  );

  getIt.registerLazySingleton<ReviewViewModel>(
    () => ReviewViewModel(emailUseCase: getIt<EmailUseCase>()),
  );
}
