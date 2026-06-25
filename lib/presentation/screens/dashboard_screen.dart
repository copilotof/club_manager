// lib/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'attendance_screen.dart';
import 'competitions_screen.dart'; // ✅ أضف هذا الاستيراد
import 'financial_dashboard_screen.dart';
import 'print_qr_codes_screen.dart';
import 'settings_screen.dart';
import 'payments_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
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
/*      
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              context.push('/qr_scanner');
            },
          ),
   */
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrintQRCodesScreen()),
              );
            },
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          // ✅ استخدام SingleChildScrollView للتجاوب
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
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
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
                    MaterialPageRoute(
                      builder: (_) => const FinancialDashboardScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // ✅ زر البطولات والمسابقات (جديد)
              _buildDashboardButton(
                context,
                icon: Icons.emoji_events,
                label: 'البطولات والمسابقات',
                color: Colors.purple,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompetitionsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
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
