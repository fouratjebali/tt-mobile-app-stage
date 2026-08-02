import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tt_mail_assistant/core/config/api_config.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service_impl.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/data/repositories/auth_repository_impl.dart';
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
  getIt.registerLazySingleton<GoogleAuthDataSource>(GoogleAuthDataSource.new);
  getIt.registerLazySingleton<BackendAuthDataSource>(
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