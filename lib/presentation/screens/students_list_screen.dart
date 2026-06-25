// lib/presentation/screens/students_list_screen.dart
import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../data/repositories/student_repository.dart';
import '../bloc/student/student_bloc.dart';
import '../bloc/student/events/student_event.dart';
import '../bloc/student/states/student_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../data/models/student_model.dart';
import '../../injection/dependency_injection.dart';
import 'add_edit_student_screen.dart';
import 'qr_scanner_screen.dart';
import 'student_profile_screen.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  late StudentBloc _studentBloc;
  final TextEditingController _searchController = TextEditingController();
  late StudentRepository _studentRepo;

  @override
  void initState() {
    super.initState();
    _studentBloc = StudentBloc(getIt());
    _studentBloc.add(LoadStudentsEvent());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
  }

  @override
  void dispose() {
    _studentBloc.close();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ دالة التعديل
  void _editStudent(StudentModel student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditStudentScreen(student: student)),
    );
    if (result == true && mounted) {
      _studentBloc.add(LoadStudentsEvent());
    }
  }

  void _showDeleteDialog(int studentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الطالب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _studentBloc.add(DeleteStudentEvent(studentId));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

// ==================== الحصول على معرف المدرسة ====================
  String _getSchoolId() {
    // يمكن تخزين معرف المدرسة في الإعدادات
    // أو استخدام معرف ثابت
    return 'SCHOOL_001'; // معرف افتراضي (يمكن تغييره من الإعدادات)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ResponsiveUtils.isMobile(context)
            ? const Text('الطلبة')
            : const Text('قائمة الطلبة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScannerScreen(
                    key: _qrScannerKey, // ✅ تمرير الـ key
                    onScan: (ScanResult scanResult) {
                      // ✅ معالجة النتيجة فوراً
                      _handleQRScan(scanResult);
                    },
                  ),
                ),
              );
              if (result != null && mounted) {
                // ✅ محاولة قراءة البيانات المشفرة
                try {
                  final Map<String, dynamic> data = jsonDecode(result);
                  final String schoolId = data['school_id'];
                  final int studentId = data['student_id'];

                  // ✅ التحقق من معرف المدرسة
                  if (schoolId == _getSchoolId()) {
                    // ✅ جلب بيانات الطالب
                    final student =
                        await _studentRepo.getStudentById(studentId);
                    if (student != null) {
                      _showStudentQRResult(student);
                    } else {
                      CustomSnackbar.showError(context, 'الطالب غير موجود');
                    }
                  } else {
                    CustomSnackbar.showError(
                        context, 'هذا الكود من مدرسة أخرى');
                  }
                } catch (e) {
                  // ✅ إذا كان الكود قديماً (رقم فقط)
                  final studentId = int.tryParse(result);
                  if (studentId != null) {
                    final student =
                        await _studentRepo.getStudentById(studentId);
                    if (student != null) {
                      _showStudentQRResult(student);
                    } else {
                      CustomSnackbar.showError(context, 'الطالب غير موجود');
                    }
                  } else {
                    CustomSnackbar.showError(context, 'كود غير صالح');
                  }
                }
              }
            },
            tooltip: 'مسح QR للطالب',
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 شريط البحث
          Padding(
            padding: EdgeInsets.all(
              ResponsiveUtils.responsiveSpacing(context, spacing: 12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو اللقب...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _studentBloc.add(LoadStudentsEvent());
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _studentBloc.add(LoadStudentsEvent());
                } else {
                  _studentBloc.add(SearchStudentsEvent(value));
                }
              },
            ),
          ),

          Expanded(
            child: BlocConsumer<StudentBloc, StudentState>(
              bloc: _studentBloc,
              listener: (context, state) {
                if (state is StudentError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
                if (state is StudentOperationSuccess) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                if (state is StudentLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is StudentsLoaded) {
                  if (state.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا يوجد طلبة',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ✅ هنا تم دمج الإحصائيات بشكل ديناميكي وصحيح بناءً على حالة الـ Bloc
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFC62828)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              Icons.people,
                              '${state.students.length}',
                              'إجمالي الطلبة',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildStatItem(
                              Icons.cake,
                              _calculateAverageAge(state.students),
                              'متوسط العمر',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            _buildStatItem(
                              Icons.wc,
                              _countGenders(state.students),
                              'ذكور / إناث',
                            ),
                          ],
                        ),
                      ),

                      // عرض القوائم المتجاوبة تحت الإحصائيات
                      Expanded(
                        child: ResponsiveLayout(
                          mobileLayout: _buildMobileList(state.students),
                          tabletLayout: _buildTabletList(state.students),
                          desktopLayout: _buildDesktopList(state.students),
                        ),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
          );
          if (result == true && mounted) {
            _studentBloc.add(LoadStudentsEvent());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _handleQRScan(ScanResult scanResult) async {
    try {
      // محاولة قراءة البيانات المشفرة
      final Map<String, dynamic> data = jsonDecode(scanResult.studentId);
      final String schoolId = data['school_id'];
      final int studentId = data['student_id'];

      if (schoolId == _getSchoolId()) {
        final student = await _studentRepo.getStudentById(studentId);
        if (student != null) {
          _showStudentQRResult(student);
        } else {
// ✅ عرض رسالة خطأ وإعادة تفعيل المسح
          CustomSnackbar.showError(context, 'الطالب غير موجود');
          _resumeScanner();
        }
      } else {
        CustomSnackbar.showError(context, 'هذا الكود من مدرسة أخرى');
        _resumeScanner();
      }
    } catch (e) {
      // إذا كان الكود قديماً (رقم فقط)
      final studentId = int.tryParse(scanResult.studentId);
      if (studentId != null) {
        final student = await _studentRepo.getStudentById(studentId);
        if (student != null) {
          _showStudentQRResult(student);
        } else {
          CustomSnackbar.showError(context, 'الطالب غير موجود');
          _resumeScanner();
        }
      } else {
        CustomSnackbar.showError(context, 'كود غير صالح');
        _resumeScanner();
      }
    }
  }

// ✅ مفتاح للوصول إلى QRScannerScreen
  final GlobalKey<QRScannerScreenState> _qrScannerKey =
      GlobalKey<QRScannerScreenState>();

// ==================== إعادة تفعيل الماسح ====================
  void _resumeScanner() {
    // QRScannerScreenState.resumeScanningStatic();

    print('🔄 محاولة إعادة تفعيل الماسح');

    // ✅ الطريقة الأولى: باستخدام الـ GlobalKey
    if (_qrScannerKey.currentState != null) {
      _qrScannerKey.currentState!.resumeScanning();
      print('✅ تم إعادة تفعيل الماسح عبر الـ key');
      return;
    }
  }

  // ✅ تم تمرير الـ index من الـ Builder إلى الدالة بالأسفل
  Widget _buildMobileList(List<StudentModel> students) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.responsiveSpacing(context, spacing: 12),
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student, index);
      },
    );
  }

  // ✅ تم تمرير الـ index هنا أيضاً
  Widget _buildTabletList(List<StudentModel> students) {
    return GridView.builder(
      padding: EdgeInsets.all(
        ResponsiveUtils.responsiveSpacing(context, spacing: 16),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student, index);
      },
    );
  }

  // ✅ تم تمرير الـ index هنا أيضاً
  Widget _buildDesktopList(List<StudentModel> students) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.4,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student, index);
      },
    );
  }

  // ✅ استقبال الـ index كمعامل ثاني لمعادلة الـ Duration
  Widget _buildStudentCard(StudentModel student, int index) {
    return FadeInUp(
      duration: Duration(milliseconds: 300 + (index * 50)),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            context.push('/student/${student.id}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE53935).withOpacity(0.1),
                      child: Text(
                        student.firstName.isNotEmpty
                            ? student.firstName[0]
                            : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'العمر: ${student.age} سنة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDialog(student.id!);
                        } else if (value == 'edit') {
                          _editStudent(student);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ عرض القاعة والفوج
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (student.hallId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.business,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'قاعة ${student.hallId}', // يمكن جلب الاسم من قاعدة البيانات
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (student.groupId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group,
                              size: 12,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'فوج ${student.groupId}', // يمكن جلب الاسم من قاعدة البيانات
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.phone,
                        student.parentPhone ?? 'رقم غير مسجل',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(Icons.cake, '${student.age} سنة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🛠️ الدوال الإضافية الخاصة بالإحصائيات
  // ==========================================

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
        ),
      ],
    );
  }

  String _calculateAverageAge(List<StudentModel> students) {
    if (students.isEmpty) return '0';
    final totalAge = students.fold<int>(0, (sum, student) => sum + student.age);
    return (totalAge / students.length).toStringAsFixed(1);
  }

  String _countGenders(List<StudentModel> students) {
    try {
      int males = students
          .where(
            (s) =>
                (s as dynamic).gender == 'male' ||
                (s as dynamic).gender == 'ذكر',
          )
          .length;
      int females = students.length - males;
      return '$males / $females';
    } catch (_) {
      return '- / -';
    }
  }

  void _showStudentQRResult(StudentModel student) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${student.firstName} ${student.lastName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'العمر: ${student.age} سنة',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // ✅ إغلاق النافذة أولاً
                      Navigator.pop(context);

                      // ✅ الانتظار قليلاً ثم فتح ملف الطالب
                      await Future.delayed(const Duration(milliseconds: 100));

                      // ✅ فتح ملف الطالب
                      await context.push('/student/${student.id}');

                      // ✅ بعد العودة من ملف الطالب، إعادة تفعيل المسح
                      _resumeScanner();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'فتح',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // ✅ إعادة تفعيل المسح بعد إغلاق النافذة
                      _resumeScanner();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
