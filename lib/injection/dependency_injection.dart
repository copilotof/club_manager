// lib/injection/dependency_injection.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/datasources/local/app_database.dart';
import '../data/datasources/remote/supabase_client.dart';
import '../data/repositories/student_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/competition_repository.dart';
import '../data/repositories/belt_repository.dart';
import '../data/repositories/hall_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/notification_repository.dart'; // ✅ إضافة
import '../domain/repositories/i_student_repository.dart';
import '../domain/repositories/i_attendance_repository.dart';
import '../domain/repositories/i_sync_repository.dart';
import '../domain/repositories/i_payment_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Shared Preferences
  // ✅ التحقق من تسجيل SharedPreferences قبل إضافته
  if (!getIt.isRegistered<SharedPreferences>()) {
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  }
  // ✅ التحقق من تسجيل Connectivity
  if (!getIt.isRegistered<Connectivity>()) {
    getIt.registerLazySingleton<Connectivity>(() => Connectivity());
  }

  // قاعدة البيانات المحلية
  // ✅ التحقق من تسجيل AppDatabase
  if (!getIt.isRegistered<AppDatabase>()) {
    final appDatabase = AppDatabase();
    await appDatabase.initialize();
    getIt.registerLazySingleton<AppDatabase>(() => appDatabase);
  }

  // Supabase (سحابي)
  // ✅ التحقق من تسجيل SupabaseClient
  if (!getIt.isRegistered<SupabaseClient>()) {
    final supabaseClient = SupabaseClient();
    await supabaseClient.initialize();
    getIt.registerLazySingleton<SupabaseClient>(() => supabaseClient);
  }

  // المستودعات (Repositories)
  // ✅ المستودعات - نستخدم isRegistered للتحقق
  if (!getIt.isRegistered<IStudentRepository>()) {
    getIt.registerLazySingleton<IStudentRepository>(
      () => StudentRepository(
        localDb: getIt<AppDatabase>(),
        remoteApi: getIt<SupabaseClient>(),
      ),
    );
  }

  if (!getIt.isRegistered<IAttendanceRepository>()) {
    getIt.registerLazySingleton<IAttendanceRepository>(
      () => AttendanceRepository(
        localDb: getIt<AppDatabase>(),
        remoteApi: getIt<SupabaseClient>(),
        connectivity: getIt<Connectivity>(),
      ),
    );
  }

  if (!getIt.isRegistered<ISyncRepository>()) {
    getIt.registerLazySingleton<ISyncRepository>(
      () => SyncRepository(
        localDb: getIt<AppDatabase>(),
        remoteApi: getIt<SupabaseClient>(),
        connectivity: getIt<Connectivity>(),
      ),
    );
  }

  if (!getIt.isRegistered<IPaymentRepository>()) {
    getIt.registerLazySingleton<IPaymentRepository>(
      () => PaymentRepository(localDb: getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<CompetitionRepository>()) {
    getIt.registerLazySingleton<CompetitionRepository>(
      () => CompetitionRepository(localDb: getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<BeltRepository>()) {
    getIt.registerLazySingleton<BeltRepository>(
      () => BeltRepository(localDb: getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<HallRepository>()) {
    getIt.registerLazySingleton<HallRepository>(
      () => HallRepository(localDb: getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<GroupRepository>()) {
    getIt.registerLazySingleton<GroupRepository>(
      () => GroupRepository(localDb: getIt<AppDatabase>()),
    );
  }

  if (!getIt.isRegistered<NotificationRepository>()) {
    getIt.registerLazySingleton<NotificationRepository>(
      () => NotificationRepository(localDb: getIt<AppDatabase>()),
    );
  }
}
/* // lib/injection/dependency_injection.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/datasources/local/app_database.dart';
import '../data/datasources/remote/supabase_client.dart';
import '../data/repositories/student_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../domain/repositories/i_payment_repository.dart';
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

  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepository(localDb: getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<ISyncRepository>(
    () => SyncRepository(
      localDb: getIt<AppDatabase>(),
      remoteApi: getIt<SupabaseClient>(),
      connectivity: getIt<Connectivity>(),
    ),
  );
  getIt.registerLazySingleton<IPaymentRepository>(
    () => PaymentRepository(localDb: getIt<AppDatabase>()),
  );
}
 */
