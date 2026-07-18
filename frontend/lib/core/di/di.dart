import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/local/auth_secure_storage.dart';
import 'package:tt_mail_assistant/data/datasources/remote/backend_auth_data_source.dart';
import 'package:tt_mail_assistant/data/datasources/remote/google_auth_data_source.dart';
import 'package:tt_mail_assistant/data/repositories/auth_repository_impl.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  if (getIt.isRegistered<AuthUseCase>()) return;

  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<AuthSecureStorage>(
    () => AuthSecureStorage(getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<GoogleAuthDataSource>(GoogleAuthDataSource.new);
  getIt.registerLazySingleton<BackendAuthDataSource>(BackendAuthDataSource.new);
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
}
