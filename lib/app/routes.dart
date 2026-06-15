// lib/app/routes.dart (أضف هذه الأسطر الجديدة)
import 'package:go_router/go_router.dart';
import '../presentation/screens/add_edit_student_screen.dart';
import '../presentation/screens/payments_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/dashboard_screen.dart';
import '../presentation/screens/students_list_screen.dart';
import '../presentation/screens/student_profile_screen.dart';
import '../presentation/screens/attendance_screen.dart';
import '../presentation/screens/qr_scanner_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/students',
      name: 'students',
      builder: (context, state) => const StudentsListScreen(), // ✅ أضف هذا
    ),
    GoRoute(
      path: '/student/:id',
      name: 'student_profile',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return StudentProfileScreen(studentId: id);
      },
    ),

    /*     GoRoute(
      path: '/attendance/:groupId/:date',
      name: 'attendance',
      builder: (context, state) {
        final groupId = int.parse(state.pathParameters['groupId']!);
        final date = DateTime.parse(state.pathParameters['date']!);
        return AttendanceScreen(groupId: groupId, date: date);
      },
    ), */
    GoRoute(
      path: '/attendance',
      name: 'attendance',
      builder: (context, state) => const AttendanceScreen(),
    ),

    GoRoute(
      path: '/qr_scanner',
      name: 'qr_scanner',
      builder: (context, state) => const QRScannerScreen(),
    ),
    GoRoute(
      path: '/add-student',
      name: 'add_student',
      builder: (context, state) => const AddEditStudentScreen(),
    ),
    GoRoute(
      path: '/edit-student/:id',
      name: 'edit_student',
      builder: (context, state) {
        // سننشئ طريقة لجلب الطالب لاحقاً
        return const AddEditStudentScreen();
      },
    ),

    GoRoute(
      path: '/payments',
      name: 'payments',
      builder: (context, state) => const PaymentsScreen(),
    ),
    GoRoute(
      path: '/student-payments/:id',
      name: 'student_payments',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PaymentsScreen(studentId: id);
      },
    ),
  ],
);
