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
    // مؤقت: بيانات تجريبية (سيتم جلبها من قاعدة البيانات لاحقاً)
    return [];
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
        ),
        subtitle: Text(
          '${participation.ageCategory} - ${participation.weightCategory.toStringAsFixed(0)} كغ',
        ),
        trailing: Text(
          participation.resultName,
          style: TextStyle(
            color: participation.resultColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
