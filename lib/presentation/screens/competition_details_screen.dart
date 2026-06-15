// lib/presentation/screens/competition_details_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/competition_model.dart';
import '../../data/models/participation_model.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';
import 'add_participation_screen.dart';

class CompetitionDetailsScreen extends StatefulWidget {
  final CompetitionModel competition;
  const CompetitionDetailsScreen({super.key, required this.competition});

  @override
  State<CompetitionDetailsScreen> createState() =>
      _CompetitionDetailsScreenState();
}

class _CompetitionDetailsScreenState extends State<CompetitionDetailsScreen> {
  late CompetitionRepository _competitionRepo;
  late StudentRepository _studentRepo;

  List<ParticipationModel> _participations = [];
  List<StudentModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _competitionRepo = CompetitionRepository(localDb: getIt());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب المشاركات
      _participations = await _getParticipations();

      // جلب الطلاب
      _students = await _studentRepo.getAllStudents();
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<ParticipationModel>> _getParticipations() async {
    try {
      final repo = CompetitionRepository(localDb: getIt());
      final participations = await repo.getParticipationsByCompetition(
        widget.competition.id!,
      );
      print('📊 عدد المشاركات في البطولة: ${participations.length}');
      return participations;
    } catch (e) {
      print('❌ خطأ في جلب المشاركات: $e');
      return [];
    }
  }

  StudentModel? _getStudentById(int id) {
    try {
      return _students.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competition.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddParticipationScreen(
                    competitionId: widget.competition.id!,
                    competition: widget.competition,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },

            tooltip: 'إضافة مشارك',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات البطولة
                  _buildCompetitionInfo(),

                  const SizedBox(height: 24),

                  // قائمة المشاركين
                  const Text(
                    'المشاركون',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_participations.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Icon(
                            Icons.people_outline,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا يوجد مشاركون',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            /*                             
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddParticipationScreen(
                                    competitionId: widget.competition.id!,
                                    competition: widget.competition,
                                  ),
                                ),
                              );
                            },
           */
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddParticipationScreen(
                                    competitionId: widget.competition.id!,
                                    competition: widget.competition,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadData();
                              }
                            },

                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مشارك'),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _participations.length,
                      itemBuilder: (context, index) {
                        final participation = _participations[index];
                        final student = _getStudentById(
                          participation.studentId,
                        );
                        return _buildParticipationCard(participation, student);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCompetitionInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.competition.typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.competition.typeName,
                    style: TextStyle(color: widget.competition.typeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              '${widget.competition.startDate.day}/${widget.competition.startDate.month}/${widget.competition.startDate.year} - ${widget.competition.endDate.day}/${widget.competition.endDate.month}/${widget.competition.endDate.year}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, widget.competition.location),
            if (widget.competition.notes != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.note, widget.competition.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  /* 
  Widget _buildParticipationCard(
    ParticipationModel participation,
    StudentModel? student,
  ) {
    // ✅ تأكد من أن البطولة انتهت (تاريخ النهاية قبل اليوم)
    final isCompetitionEnded = widget.competition.endDate.isBefore(
      DateTime.now(),
    );

    print('📅 تاريخ نهاية البطولة: ${widget.competition.endDate}');
    print('📅 اليوم: ${DateTime.now()}');
    print('🏁 هل انتهت البطولة؟ $isCompetitionEnded');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: participation.resultColor.withOpacity(0.1),
          child: Text(
            participation.result == 'gold'
                ? '🥇'
                : participation.result == 'silver'
                ? '🥈'
                : participation.result == 'bronze'
                ? '🥉'
                : '📋',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          student?.fullName ?? 'طالب غير معروف',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${participation.ageCategory} - ${participation.weightCategory.toStringAsFixed(0)} كغ',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              participation.resultName,
              style: TextStyle(
                color: participation.resultColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            // ✅ زر تعديل النتيجة (يظهر دائماً، وليس فقط بعد انتهاء البطولة)
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _editResult(participation),
              tooltip: 'تعديل النتيجة',
            ),
            // ✅ زر حذف المشاركة
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              onPressed: () => _deleteParticipation(participation),
              tooltip: 'إلغاء المشاركة',
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildParticipationCard(
    ParticipationModel participation,
    StudentModel? student,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: participation.resultColor.withOpacity(0.1),
          child: Text(
            participation.result == 'gold'
                ? '🥇'
                : participation.result == 'silver'
                ? '🥈'
                : participation.result == 'bronze'
                ? '🥉'
                : '📋',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          student?.fullName ?? 'طالب غير معروف',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${participation.ageCategory} - ${participation.weightCategory.toStringAsFixed(0)} كغ',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: participation.resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                participation.resultName,
                style: TextStyle(
                  fontSize: 12,
                  color: participation.resultColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _editResult(participation),
              tooltip: 'تعديل النتيجة',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              onPressed: () => _deleteParticipation(participation),
              tooltip: 'إلغاء المشاركة',
            ),
          ],
        ),
      ),
    );
  }
*/

  Widget _buildParticipationCard(
    ParticipationModel participation,
    StudentModel? student,
  ) {
    final isCompetitionEnded = widget.competition.endDate.isBefore(
      DateTime.now(),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 1. أيقونة النتيجة (يسار)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: participation.resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  participation.rank == 1
                      ? '🥇'
                      : participation.rank == 2
                      ? '🥈'
                      : participation.rank == 3
                      ? '🥉'
                      : '📋',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // 2. معلومات الطالب (وسط - يأخذ المساحة المتبقية)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student?.fullName ?? 'طالب غير معروف',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${participation.ageCategory} • ${participation.weightCategory.toStringAsFixed(0)} كغ',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 3. النتيجة والأزرار (يمين)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // الرتبة
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: participation.resultColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    participation.resultName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: participation.resultColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // الأزرار
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // زر تعديل النتيجة (يظهر فقط بعد انتهاء البطولة)
                    if (isCompetitionEnded)
                      InkWell(
                        onTap: () => _editResult(participation),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit, size: 18, color: Colors.blue),
                        ),
                      ),
                    // زر حذف المشاركة
                    InkWell(
                      onTap: () => _deleteParticipation(participation),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteParticipation(ParticipationModel participation) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء المشاركة'),
        content: Text(
          'هل أنت متأكد من إلغاء مشاركة ${_getStudentById(participation.studentId)?.fullName ?? 'الطالب'}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = CompetitionRepository(localDb: getIt());
      await repo.deleteParticipation(participation.id!);
      await _loadData();
      CustomSnackbar.showSuccess(context, 'تم إلغاء المشاركة');
    }
  }
  /* 
  void _editResult(ParticipationModel participation) async {
    final newResult = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل النتيجة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر النتيجة الجديدة:'),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gold', label: Text('🥇 ذهبية')),
                ButtonSegment(value: 'silver', label: Text('🥈 فضية')),
                ButtonSegment(value: 'bronze', label: Text('🥉 برونزية')),
                ButtonSegment(value: 'participation', label: Text('📋 مشاركة')),
              ],
              selected: {participation.result},
              onSelectionChanged: (Set<String> selection) {
                Navigator.pop(context, selection.first);
              },
            ),
          ],
        ),
      ),
    );

    if (newResult != null && newResult != participation.result) {
      // تحديث النتيجة في قاعدة البيانات
      final updatedParticipation = ParticipationModel(
        id: participation.id,
        competitionId: participation.competitionId,
        studentId: participation.studentId,
        specialtyId: participation.specialtyId,
        ageCategory: participation.ageCategory,
        weightCategory: participation.weightCategory,
        result: newResult,
        rank: newResult == 'gold'
            ? 1
            : (newResult == 'silver' ? 2 : (newResult == 'bronze' ? 3 : null)),
        medalType: newResult != 'participation' ? newResult : null,
        notes: participation.notes,
        createdAt: participation.createdAt,
      );

      final repo = CompetitionRepository(localDb: getIt());
      await repo.updateParticipation(updatedParticipation);
      await _loadData();
      CustomSnackbar.showSuccess(context, 'تم تحديث النتيجة');
    }
  }
 
void _editResult(ParticipationModel participation) async {
  final newResult = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تعديل النتيجة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('اختر النتيجة الجديدة:'),
          const SizedBox(height: 16),
          // ✅ استخدام Wrap بدلاً من SegmentedButton لتجنب التجاوز
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildResultChip('gold', '🥇 ذهبية', participation.result),
              _buildResultChip('silver', '🥈 فضية', participation.result),
              _buildResultChip('bronze', '🥉 برونزية', participation.result),
              _buildResultChip('participation', '📋 مشاركة', participation.result),
            ],
          ),
        ],
      ),
    ),
  );
  
  if (newResult != null && newResult != participation.result) {
    final updatedParticipation = ParticipationModel(
      id: participation.id,
      competitionId: participation.competitionId,
      studentId: participation.studentId,
      specialtyId: participation.specialtyId,
      ageCategory: participation.ageCategory,
      weightCategory: participation.weightCategory,
      result: newResult,
      rank: newResult == 'gold' ? 1 : (newResult == 'silver' ? 2 : (newResult == 'bronze' ? 3 : null)),
      medalType: newResult != 'participation' ? newResult : null,
      notes: participation.notes,
      createdAt: participation.createdAt,
    );
    
    final repo = CompetitionRepository(localDb: getIt());
    await repo.updateParticipation(updatedParticipation);
    await _loadData();
    if (!mounted) return;
    CustomSnackbar.showSuccess(context, 'تم تحديث النتيجة');
  }
}
*/

  void _editResult(ParticipationModel participation) async {
    final newRank = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل النتيجة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر الرتبة التي حصل عليها المشارك:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRankChip(1, '🥇 الرتبة 1 (ذهبية)', participation.rank),
                _buildRankChip(2, '🥈 الرتبة 2 (فضية)', participation.rank),
                _buildRankChip(3, '🥉 الرتبة 3 (برونزية)', participation.rank),
                _buildRankChip(
                  null,
                  '📋 مشاركة (بدون رتبة)',
                  participation.rank,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (newRank != null && newRank != participation.rank) {
      String result = 'participation';
      if (newRank == 1)
        result = 'gold';
      else if (newRank == 2)
        result = 'silver';
      else if (newRank == 3)
        result = 'bronze';

      final updatedParticipation = ParticipationModel(
        id: participation.id,
        competitionId: participation.competitionId,
        studentId: participation.studentId,
        specialtyId: participation.specialtyId,
        ageCategory: participation.ageCategory,
        weightCategory: participation.weightCategory,
        result: result,
        rank: newRank,
        medalType: newRank != null && newRank <= 3
            ? (newRank == 1
                  ? 'gold'
                  : newRank == 2
                  ? 'silver'
                  : 'bronze')
            : null,
        notes: participation.notes,
        createdAt: participation.createdAt,
      );

      final repo = CompetitionRepository(localDb: getIt());
      await repo.updateParticipation(updatedParticipation);
      await _loadData();
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        context,
        newRank != null && newRank <= 3
            ? 'تم تحديث الرتبة إلى ${newRank}'
            : 'تم تحديث إلى مشاركة فقط',
      );
    }
  }

  Widget _buildRankChip(int? rank, String label, int? currentRank) {
    return FilterChip(
      label: Text(label),
      selected: currentRank == rank,
      onSelected: (selected) {
        if (selected) {
          Navigator.pop(context, rank);
        }
      },
      selectedColor: const Color(0xFFE53935).withOpacity(0.2),
    );
  }

  Widget _buildResultChip(String value, String label, String currentResult) {
    return FilterChip(
      label: Text(label),
      selected: currentResult == value,
      onSelected: (selected) {
        if (selected) {
          Navigator.pop(context, value);
        }
      },
      selectedColor: const Color(0xFFE53935).withOpacity(0.2),
    );
  }
}
