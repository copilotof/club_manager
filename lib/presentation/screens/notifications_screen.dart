// lib/presentation/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/notification/notification_bloc.dart';
import '../bloc/notification/events/notification_event.dart';
import '../bloc/notification/states/notification_state.dart';
import '../../data/models/notification_model.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../injection/dependency_injection.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late NotificationBloc _notificationBloc;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _notificationBloc = NotificationBloc(getIt());
    _tabController = TabController(length: 2, vsync: this);
    _notificationBloc.add(LoadNotificationsEvent());
  }

  @override
  void dispose() {
    _notificationBloc.close();
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return DateFormat('yyyy/MM/dd', 'en_US').format(date);
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 2:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الكل', icon: Icon(Icons.notifications)),
            Tab(text: 'غير مقروءة', icon: Icon(Icons.circle)),
          ],
        ),
        actions: [
          // زر تحديث
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _notificationBloc.add(LoadNotificationsEvent());
            },
            tooltip: 'تحديث',
          ),
          // زر حذف الكل
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all_read') {
                _showDeleteAllReadDialog();
              } else if (value == 'mark_all_read') {
                _notificationBloc.add(MarkAllAsReadEvent());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('تحديد الكل كمقروء'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all_read',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('حذف المقروءة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        bloc: _notificationBloc,
        listener: (context, state) {
          if (state is NotificationOperationSuccess) {
            CustomSnackbar.showSuccess(context, state.message);
          }
          if (state is NotificationError) {
            CustomSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationsLoaded) {
            final notifications = state.notifications;

            if (notifications.isEmpty) {
              return _buildEmptyState();
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // تبويب الكل
                _buildNotificationsList(notifications),
                // تبويب غير مقروءة
                _buildNotificationsList(
                  notifications.where((n) => !n.isRead).toList(),
                ),
              ],
            );
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في تحميل الإشعارات',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _notificationBloc.add(LoadNotificationsEvent());
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// بناء شاشة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الإشعارات هنا عند حدوث أحداث مهمة',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// بناء قائمة الإشعارات
  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  /// بناء بطاقة الإشعار
  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification.isRead
            ? BorderSide.none
            : BorderSide(
                color: _getPriorityColor(notification.priority),
                width: 2,
              ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(notification.type),
          child: Text(
            notification.typeIcon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight:
                      notification.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getPriorityColor(notification.priority),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  notification.typeName,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getTypeColor(notification.type),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(notification.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (value) {
            if (value == 'mark_read') {
              if (!notification.isRead) {
                _notificationBloc.add(MarkAsReadEvent(notification.id!));
              }
            } else if (value == 'delete') {
              _showDeleteDialog(notification.id!);
            }
          },
          itemBuilder: (context) => [
            if (!notification.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.done, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('تحديد كمقروء'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // وضع علامة مقروء عند النقر
          if (!notification.isRead) {
            _notificationBloc.add(MarkAsReadEvent(notification.id!));
          }
          // التنقل إلى الصفحة المرتبطة (إذا وجدت)
          if (notification.actionUrl != null) {
            // context.push(notification.actionUrl!);
          }
        },
      ),
    );
  }

  /// الحصول على لون النوع
  Color _getTypeColor(String type) {
    switch (type) {
      case 'payment':
        return Colors.green;
      case 'attendance':
        return Colors.orange;
      case 'competition':
        return Colors.purple;
      case 'belt':
        return Colors.blue;
      case 'general':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// نافذة تأكيد حذف إشعار
  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الإشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _notificationBloc.add(DeleteNotificationEvent(id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  /// نافذة تأكيد حذف الإشعارات المقروءة
  void _showDeleteAllReadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف جميع الإشعارات المقروءة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _notificationBloc.add(DeleteAllReadEvent());
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
