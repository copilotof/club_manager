import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive_utils.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              context.push('/qr_scanner');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // ✅ مهم جداً!
        padding: EdgeInsets.all(
          ResponsiveUtils.responsiveSpacing(context, spacing: 16),
        ),
        child: Column(
          children: [
            Center(
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
                      // مثال: الفوج رقم 1 وتاريخ اليوم
                      final today = DateTime.now()
                          .toIso8601String()
                          .split('T')
                          .first;
                      context.push('/attendance/1/$today');
                    },
                    child: const Text('تسجيل الحضور'),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      final today = DateTime.now();
                      context.push(
                        '/attendance/1/${today.toIso8601String().split('T').first}',
                      );
                    },
                    child: const Text('تسجيل الحضور (تجريبي)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
