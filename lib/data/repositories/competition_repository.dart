// lib/data/repositories/competition_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/competition_model.dart';
import '../datasources/local/app_database.dart';

class CompetitionRepository {
  final AppDatabase _localDb;

  CompetitionRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  // جلب جميع البطولات
  Future<List<CompetitionModel>> getAllCompetitions() async {
    final db = await _db;
    final result = await db.query('competitions', orderBy: 'start_date DESC');
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
