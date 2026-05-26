// lib/injection/dependency_injection.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/datasources/local/app_database.dart';
import '../data/datasources/remote/supabase_client.dart';
import '../data/repositories/student_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../domain/repositories/i_student_repository.dart';
import '../domain/repositories/i_attendance_repository.dart';
import '../domain/repositories/i_sync_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Connectivity
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // قاعدة البيانات المحلية
  final appDatabase = AppDatabase();
  await appDatabase.initialize();
  getIt.registerLazySingleton<AppDatabase>(() => appDatabase);

  // Supabase (سحابي)
  final supabaseClient = SupabaseClient();
  await supabaseClient.initialize();
  getIt.registerLazySingleton<SupabaseClient>(() => supabaseClient);

  // المستودعات (Repositories)
  getIt.registerLazySingleton<IStudentRepository>(
    () => StudentRepository(
      localDb: getIt<AppDatabase>(),
      remoteApi: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerLazySingleton<IAttendanceRepository>(
    () => AttendanceRepository(
      localDb: getIt<AppDatabase>(),
      remoteApi: getIt<SupabaseClient>(),
      connectivity: getIt<Connectivity>(),
    ),
  );

  getIt.registerLazySingleton<ISyncRepository>(
    () => SyncRepository(
      localDb: getIt<AppDatabase>(),
      remoteApi: getIt<SupabaseClient>(),
      connectivity: getIt<Connectivity>(),
    ),
  );
}
