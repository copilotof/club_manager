// lib/presentation/screens/competitions_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/competition_model.dart';
import '../../data/repositories/competition_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';
import 'add_competition_screen.dart';
import 'competition_details_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  List<CompetitionModel> _competitions = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: قادمة, 1: سابقة

  late CompetitionRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = CompetitionRepository(localDb: getIt());
    _loadCompetitions();
  }

  Future<void> _loadCompetitions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final competitions = await _repository.getAllCompetitions();
      print('📊 تم جلب ${competitions.length} بطولة');
      final now = DateTime.now();
      for (var c in competitions) {
        final status = c.endDate.isAfter(now) ? "قادمة" : "سابقة";

        print(
          '   - ${c.name} (${c.startDate.day}/${c.startDate.month}/${c.startDate.year} - ${c.endDate.day}/${c.endDate.month}/${c.endDate.year}) : $status',
        );
      }
      setState(() {
        _competitions = competitions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل البطولات: $e');
      setState(() {
        _isLoading = false;
      });
      CustomSnackbar.showError(context, 'خطأ في تحميل البطولات');
    }
  }

  List<CompetitionModel> get _upcomingCompetitions {
    final now = DateTime.now();
    return _competitions.where((c) => c.endDate.isAfter(now)).toList();
  }

  List<CompetitionModel> get _pastCompetitions {
    final now = DateTime.now();
    return _competitions.where((c) => c.endDate.isBefore(now)).toList();
  }

  Future<void> _deleteCompetition(int id, String name) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف بطولة "$name"؟'),
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
      await _repository.deleteCompetition(id);
      await _loadCompetitions();
      CustomSnackbar.showSuccess(context, 'تم حذف البطولة بنجاح');
    }
  }

  @override
  Widget build(BuildContext context) {
    /*     Future<void> _addSampleCompetition() async {
      final sampleCompetition = CompetitionModel(
        name: 'بطولة تجريبية للاختبار',
        type: 'national',
        startDate: DateTime.now().add(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 32)),
        location: 'قصر الرياضات - الجزائر',
        specialtyIds: [1, 2],
        ageCategories: ['أكابر', 'أواسط'],
        notes: 'هذه بطولة تجريبية',
      );

      final repo = CompetitionRepository(localDb: getIt());
     // await repo.addCompetition(sampleCompetition);
      await _loadCompetitions();
      CustomSnackbar.showSuccess(context, 'تم إضافة بطولة تجريبية');
    }

  */
    return Scaffold(
      appBar: AppBar(
        title: const Text('البطولات والمسابقات'),
        actions: [
          /*           IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSampleCompetition,
            tooltip: 'إضافة تجريبية',
          ), */
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCompetitions(),
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCompetitionScreen()),
              );
              if (result == true) {
                await _loadCompetitions(); // انتظر حتى يتم التحميل
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // تبويبات
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'قادمة (${_upcomingCompetitions.length})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'سابقة (${_pastCompetitions.length})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _selectedTab == 0
                        ? _upcomingCompetitions.length
                        : _pastCompetitions.length,
                    itemBuilder: (context, index) {
                      final competition = _selectedTab == 0
                          ? _upcomingCompetitions[index]
                          : _pastCompetitions[index];
                      print(
                        '📱 عرض البطولة رقم $index: ${competition.name}',
                      ); // للتصحيح

                      return _buildCompetitionCard(competition);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompetitionCard(CompetitionModel competition) {
    print('🃏 بناء بطاقة لـ: ${competition.name}'); // للتصحيح

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // TODO: فتح تفاصيل البطولة
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CompetitionDetailsScreen(competition: competition),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                      color: competition.typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      competition.typeName,
                      style: TextStyle(
                        fontSize: 12,
                        color: competition.typeColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  //     شرط ظهور "قادمة":
                  if (competition.endDate.isAfter(DateTime.now()))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'قادمة',
                        style: TextStyle(fontSize: 12, color: Colors.green),
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
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await _deleteCompetition(
                          competition.id!,
                          competition.name,
                        );
                      } else if (value == 'edit') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddCompetitionScreen(competition: competition),
                          ),
                        );
                        if (result == true) {
                          _loadCompetitions();
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                competition.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${competition.startDate.day}/${competition.startDate.month}/${competition.startDate.year} - ${competition.endDate.day}/${competition.endDate.month}/${competition.endDate.year}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      competition.location,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
