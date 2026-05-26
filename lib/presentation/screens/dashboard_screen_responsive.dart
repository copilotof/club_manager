// lib/presentation/screens/dashboard_screen_responsive.dart
import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

class DashboardScreenResponsive extends StatelessWidget {
  const DashboardScreenResponsive({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ResponsiveUtils.isMobile(context)
            ? const Text('الرئيسية')
            : const Text('لوحة التحكم - Fight Club Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () {}),
        ],
      ),
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(context),
        tabletLayout: _buildTabletLayout(context),
        desktopLayout: _buildDesktopLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(
        ResponsiveUtils.responsiveSpacing(context, spacing: 16),
      ),
      children: [
        _buildStatCard('إجمالي الطلبة', '150', Icons.people),
        const SizedBox(height: 12),
        _buildStatCard('الحضور اليوم', '45', Icons.check_circle),
        const SizedBox(height: 12),
        _buildStatCard('المتأخرات', '12,500 دج', Icons.warning),
        const SizedBox(height: 12),
        _buildStatCard('بطولات قادمة', '3', Icons.emoji_events),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.all(
        ResponsiveUtils.responsiveSpacing(context, spacing: 20),
      ),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('إجمالي الطلبة', '150', Icons.people),
        _buildStatCard('الحضور اليوم', '45', Icons.check_circle),
        _buildStatCard('المتأخرات', '12,500 دج', Icons.warning),
        _buildStatCard('بطولات قادمة', '3', Icons.emoji_events),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _buildStatCard('إجمالي الطلبة', '150', Icons.people),
                _buildStatCard('الحضور اليوم', '45', Icons.check_circle),
                _buildStatCard('المتأخرات', '12,500 دج', Icons.warning),
                _buildStatCard('بطولات قادمة', '3', Icons.emoji_events),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الأنشطة الأخيرة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('تم إضافة طالب جديد'),
                      subtitle: Text(
                        'أحمد محمد - ${DateTime.now().toString().split(' ')[0]}',
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: const Text('بطولة قادمة'),
                      subtitle: const Text('بطولة الجزائر الوطنية - 10 يونيو'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFFE53935)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
