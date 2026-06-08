// lib/presentation/screens/dashboard_screen.dart
import 'package:fight_club_manager/presentation/screens/financial_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'settings_screen.dart'; // ✅ أضف هذا الاستيراد

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          // ✅ زر الإعدادات
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              context.push('/qr_scanner');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('مرحباً بك في لوحة التحكم'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.push('/students');
              },
              child: const Text('إدارة الطلبة'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                final today = DateTime.now();
                context.push(
                  '/attendance/1/${today.toIso8601String().split('T').first}',
                );
              },
              child: const Text('تسجيل الحضور (تجريبي)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FinancialDashboardScreen(),
                  ),
                );
                //  context.push('/payments');
              },
              child: const Text('الدفعات المالية'),
            ),
          ],
        ),
      ),
    );
  }
}
