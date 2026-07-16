import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  // This is where we will register all our dependencies
  // for the Domain, Data, and Presentation layers.

  // Example: getIt.registerLazySingleton<MyRepository>(() => MyRepositoryImpl());
}
