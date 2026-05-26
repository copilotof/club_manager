// lib/presentation/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/events/attendance_event.dart';
import '../bloc/attendance/states/attendance_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../data/models/attendance_record.dart';
import '../../injection/dependency_injection.dart';
import 'qr_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final int groupId;
  final DateTime date;
  const AttendanceScreen({
    super.key,
    required this.groupId,
    required this.date,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late AttendanceBloc _attendanceBloc;

  @override
  void initState() {
    super.initState();
    _attendanceBloc = AttendanceBloc(getIt());
    _attendanceBloc.add(
      LoadAttendanceEvent(groupId: widget.groupId, date: widget.date),
    );
  }

  @override
  void dispose() {
    _attendanceBloc.close();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, yyyy/MM/dd', 'ar').format(date);
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  Color _getBeltColor(String? belt) {
    if (belt == null) return Colors.grey;
    switch (belt.toLowerCase()) {
      case 'أبيض':
        return Colors.grey[300]!;
      case 'أصفر':
        return Colors.yellow;
      case 'برتقالي':
        return Colors.orange;
      case 'أخضر':
        return Colors.green;
      case 'أزرق':
        return Colors.blue;
      case 'بني':
        return Colors.brown;
      case 'أسود':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showExcuseDialog(
    int studentId,
    int groupId,
    DateTime date,
  ) async {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الغياب'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الغياب...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _attendanceBloc.add(
                MarkAbsentEvent(
                  studentId: studentId,
                  groupId: groupId,
                  date: date,
                  excuseReason: controller.text.isEmpty
                      ? null
                      : controller.text,
                ),
              );
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تأكيد الغياب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final formattedDate = _formatDate(widget.date);
    final shortDate = DateFormat('yyyy/MM/dd').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: isMobile
            ? Text('حضور - $shortDate', style: const TextStyle(fontSize: 16))
            : Text('تسجيل الحضور - $formattedDate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              );
              if (result != null && mounted) {
                _attendanceBloc.add(
                  QRScannedEvent(
                    qrData: result,
                    groupId: widget.groupId,
                    date: widget.date,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        bloc: _attendanceBloc,
        listener: (context, state) {
          if (state is AttendanceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is AttendanceSynced) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تمت المزامنة بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AttendanceLoaded) {
            return Column(
              children: [
                // شريط حالة الاتصال
                if (!state.isOnline)
                  Container(
                    width: double.infinity,
                    color: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'غير متصل – سيتم المزامنة لاحقاً',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // زر المزامنة (إذا كانت هناك عمليات معلقة)
                if (state.hasPendingSync)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // سنضيف ميزة المزامنة لاحقاً
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('مزامنة البيانات المعلقة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),

                // إحصائيات سريعة
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip(
                        'الحاضرون',
                        state.records.where((r) => r.isPresent).length,
                        Colors.green,
                      ),
                      _buildStatChip(
                        'الغائبون',
                        state.records.where((r) => !r.isPresent).length,
                        Colors.red,
                      ),
                      _buildStatChip(
                        'الإجمالي',
                        state.records.length,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),

                // قائمة الطلاب
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.records.length,
                    itemBuilder: (context, index) {
                      final record = state.records[index];
                      return _buildAttendanceCard(record, state);
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record, AttendanceLoaded state) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getBeltColor(record.beltColor),
          child: Text(
            record.studentName[0],
            style: TextStyle(
              color:
                  _getBeltColor(record.beltColor) == Colors.white ||
                      _getBeltColor(record.beltColor) == Colors.yellow
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
        title: Text('${record.studentName} ${record.studentLastName}'),
        subtitle: Text(
          record.isPresent
              ? '✅ حاضر ${record.markedAt != null ? _formatTime(record.markedAt!) : ''}'
              : (record.excuseReason != null
                    ? '❌ غائب - العذر: ${record.excuseReason}'
                    : (record.wasAutoGenerated
                          ? '❌ غائب (تلقائي)'
                          : '❌ غائب (يدوي)')),
          style: TextStyle(
            fontSize: 12,
            color: record.isPresent ? Colors.green : Colors.red,
          ),
        ),
        trailing: Switch(
          value: record.isPresent,
          onChanged: (value) {
            if (value) {
              _attendanceBloc.add(
                MarkPresentEvent(
                  studentId: record.studentId,
                  groupId: state.groupId,
                  date: state.date,
                ),
              );
            } else {
              _showExcuseDialog(record.studentId, state.groupId, state.date);
            }
          },
          activeColor: const Color(0xFFE53935),
        ),
      ),
    );
  }
}
