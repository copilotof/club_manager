// lib/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../injection/dependency_injection.dart';
import '../bloc/notification/events/notification_event.dart';
import '../bloc/notification/notification_bloc.dart';
import '../bloc/notification/states/notification_state.dart';
import 'attendance_screen.dart';
import 'competitions_screen.dart'; // ✅ أضف هذا الاستيراد
import 'financial_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'print_qr_codes_screen.dart';
import 'settings_screen.dart';
import 'payments_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc(getIt()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          actions: [
            // ✅ أيقونة الإشعارات مع عداد
            BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                int count = 0;
                if (state is NotificationCountLoaded) {
                  count = state.count;
                }
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ).then((_) {
                          // تحديث العداد عند العودة
                          context
                              .read<NotificationBloc>()
                              .add(GetUnreadCountEvent());
                        });
                      },
                      tooltip: 'الإشعارات',
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              tooltip: 'الإعدادات',
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'مرحباً بك في لوحة التحكم',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // زر إدارة الطلبة
                _buildDashboardButton(
                  context,
                  icon: Icons.people,
                  label: 'إدارة الطلبة',
                  color: Colors.blue,
                  onPressed: () => context.push('/students'),
                ),

                const SizedBox(height: 12),

                // زر تسجيل الحضور
                _buildDashboardButton(
                  context,
                  icon: Icons.checklist,
                  label: 'تسجيل الحضور',
                  color: Colors.green,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AttendanceScreen()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // زر الدفعات المالية
                _buildDashboardButton(
                  context,
                  icon: Icons.payments,
                  label: 'الدفعات المالية',
                  color: Colors.orange,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // زر البطولات والمسابقات
                _buildDashboardButton(
                  context,
                  icon: Icons.emoji_events,
                  label: 'البطولات والمسابقات',
                  color: Colors.purple,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CompetitionsScreen()),
                    );
                  },
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
