// lib/data/repositories/belt_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/belt_model.dart';
import '../datasources/local/app_database.dart';

class BeltRepository {
  final AppDatabase _localDb;

  BeltRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  // جلب جميع أحزمة طالب معين (مرتبة حسب التاريخ)
  Future<List<BeltModel>> getStudentBelts(int studentId) async {
    final db = await _db;
    final result = await db.query(
      'belts',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date_achieved DESC',
    );
    return result.map((map) => BeltModel.fromMap(map)).toList();
  }

  // إضافة حزام جديد
  Future<int> addBelt(BeltModel belt) async {
    final db = await _db;
    return await db.insert('belts', belt.toMap());
  }

  // تحديث حزام
  Future<int> updateBelt(BeltModel belt) async {
    final db = await _db;
    return await db.update(
      'belts',
      belt.toMap(),
      where: 'id = ?',
      whereArgs: [belt.id],
    );
  }

  // حذف حزام
  Future<int> deleteBelt(int id) async {
    final db = await _db;
    return await db.delete('belts', where: 'id = ?', whereArgs: [id]);
  }

  // جلب آخر حزام للطالب (أعلى ترتيب)
  Future<BeltModel?> getLatestBelt(int studentId) async {
    final db = await _db;
    final result = await db.query(
      'belts',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'order_index DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return BeltModel.fromMap(result.first);
    }
    return null;
  }
}
