// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/attendance_check_service.dart';
import 'core/services/competition_check_service.dart';
import 'core/services/notification_service.dart';
import 'data/datasources/local/app_database.dart';
import 'injection/dependency_injection.dart';
import 'app/routes.dart';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'presentation/bloc/notification/notification_bloc.dart';
import 'presentation/screens/onboarding_screen.dart';

/* // في main.dart، قبل runApp
Future<void> _cleanExtraSessions() async {
  try {
    final db = await getIt<AppDatabase>().database;
    await db.delete('extra_sessions');
    print('✅ تم حذف جميع الحصص الاستثنائية القديمة');
  } catch (e) {
    print('⚠️ خطأ في حذف الحصص الاستثنائية: $e');
  }
}
 */
/* Future<void> _resetDatabase() async {
  try {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'fight_club.db');
    final exists = await databaseExists(path);
    if (exists) {
      await deleteDatabase(path);
      print('✅ تم حذف قاعدة البيانات القديمة');
    }
  } catch (e) {
    print('⚠️ خطأ في حذف قاعدة البيانات: $e');
  }
} */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await _cleanExtraSessions();

  // await _deleteOldDatabase();
  // ✅ حذف قاعدة البيانات القديمة (مؤقتاً)
  // await _resetDatabase();

  // ✅ تهيئة التواريخ للغة العربية
  await initializeDateFormatting('ar', null);

  // تهيئة حقن التبعيات
  await setupDependencyInjection();

  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('onboarding_complete') ?? false;

  runApp(MyApp(isFirstTime: isFirstTime));
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await setupDependencyInjection();

  // ✅ تشغيل فحص التنبيهات كل 6 ساعات
  Timer.periodic(const Duration(hours: 6), (timer) {
    _runNotificationChecks();
  });

  // ✅ تشغيل فحص فوري عند بدء التطبيق
  _runNotificationChecks();

  runApp(MyApp(isFirstTime: isFirstTime));
}

void _runNotificationChecks() {
  final service = NotificationService();
  service.runAllChecks();
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;
  const MyApp({
    super.key,
    required this.isFirstTime, // التمرير إجباري هنا
  });

/*   @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fight Club Manager',
      locale: const Locale('ar', 'DZ'), // ✅ ضبط اللغة العربية
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFE53935),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: GoogleFonts.cairo().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE53935),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      routerConfig: router,
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        final shortestSide = screenSize.shortestSide;

        if (shortestSide < 360) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.85)),
            child: child!,
          );
        }
        return child!;
      },
    );
  }
 */

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // ✅ إضافة NotificationBloc
        BlocProvider<NotificationBloc>(
          create: (context) => NotificationBloc(getIt()),
        ),
        // يمكن إضافة BLoCs أخرى هنا
      ],
      child: MaterialApp.router(
        title: 'Fight Club Manager',
        locale: const Locale('ar', 'DZ'),
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFFE53935),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          fontFamily: GoogleFonts.cairo().fontFamily,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFE53935),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        routerConfig: router,
        builder: (context, child) {
          if (isFirstTime) {
            return const OnboardingScreen();
          }
          return child!;
        },
      ),
    );
  }
}
