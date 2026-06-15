// lib/data/repositories/hall_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/hall_model.dart';
import '../datasources/local/app_database.dart';

class HallRepository {
  final AppDatabase _localDb;

  HallRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  Future<List<HallModel>> getAllHalls() async {
    final db = await _db;
    final result = await db.query('halls', orderBy: 'name');
    return result.map((map) => HallModel.fromMap(map)).toList();
  }

  Future<int> addHall(HallModel hall) async {
    final db = await _db;
    return await db.insert('halls', hall.toMap());
  }

  Future<int> updateHall(HallModel hall) async {
    final db = await _db;
    return await db.update(
      'halls',
      hall.toMap(),
      where: 'id = ?',
      whereArgs: [hall.id],
    );
  }

  Future<int> deleteHall(int id) async {
    final db = await _db;
    return await db.delete('halls', where: 'id = ?', whereArgs: [id]);
  }
}
