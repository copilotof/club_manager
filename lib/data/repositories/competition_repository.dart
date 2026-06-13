// lib/data/repositories/competition_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/competition_model.dart';
import '../datasources/local/app_database.dart';
import '../models/participation_model.dart';

class CompetitionRepository {
  final AppDatabase _localDb;

  CompetitionRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  // جلب جميع البطولات
  Future<List<CompetitionModel>> getAllCompetitions() async {
    final db = await _db;
    final result = await db.query('competitions', orderBy: 'start_date DESC');
    print('📊 عدد البطولات في قاعدة البيانات: ${result.length}');
    for (var row in result) {
      print('   - ${row['name']} (${row['start_date']})');
    }
    return result.map((map) => CompetitionModel.fromMap(map)).toList();
  }

  // جلب البطولات القادمة
  Future<List<CompetitionModel>> getUpcomingCompetitions() async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final result = await db.query(
      'competitions',
      where: 'start_date > ?',
      whereArgs: [now],
      orderBy: 'start_date ASC',
    );
    return result.map((map) => CompetitionModel.fromMap(map)).toList();
  }

  // جلب البطولات السابقة
  Future<List<CompetitionModel>> getPastCompetitions() async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final result = await db.query(
      'competitions',
      where: 'end_date < ?',
      whereArgs: [now],
      orderBy: 'start_date DESC',
    );
    return result.map((map) => CompetitionModel.fromMap(map)).toList();
  }

  // إضافة بطولة جديدة
  Future<int> addCompetition(CompetitionModel competition) async {
    final db = await _db;
    return await db.insert('competitions', competition.toMap());
  }

  // تحديث بطولة
  Future<int> updateCompetition(CompetitionModel competition) async {
    final db = await _db;
    return await db.update(
      'competitions',
      competition.toMap(),
      where: 'id = ?',
      whereArgs: [competition.id],
    );
  }

  // حذف بطولة
  Future<int> deleteCompetition(int id) async {
    final db = await _db;
    return await db.delete('competitions', where: 'id = ?', whereArgs: [id]);
  }

  // إضافة مشاركة جديدة
  Future<int> addParticipation(ParticipationModel participation) async {
    final db = await _db;
    return await db.insert('participations', participation.toMap());
  }

  // جلب مشاركات بطولة معينة
  Future<List<ParticipationModel>> getParticipationsByCompetition(
    int competitionId,
  ) async {
    final db = await _db;
    final result = await db.query(
      'participations',
      where: 'competition_id = ?',
      whereArgs: [competitionId],
    );
    print('📊 جلب ${result.length} مشاركة للبطولة $competitionId');

    return result.map((map) => ParticipationModel.fromMap(map)).toList();
  }

  // تحديث مشاركة
  Future<int> updateParticipation(ParticipationModel participation) async {
    final db = await _db;
    return await db.update(
      'participations',
      participation.toMap(),
      where: 'id = ?',
      whereArgs: [participation.id],
    );
  }

  // حذف مشاركة
  Future<int> deleteParticipation(int id) async {
    final db = await _db;
    return await db.delete('participations', where: 'id = ?', whereArgs: [id]);
  }

  // جلب بطولة حسب المعرف
  Future<CompetitionModel?> getCompetitionById(int id) async {
    final db = await _db;
    final result = await db.query(
      'competitions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return CompetitionModel.fromMap(result.first);
    }
    return null;
  }
}
