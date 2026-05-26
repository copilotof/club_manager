// lib/data/repositories/student_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/student_model.dart';
import '../../domain/repositories/i_student_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_client.dart';

class StudentRepository implements IStudentRepository {
  final AppDatabase _localDb;
  final SupabaseClient _remoteApi;

  StudentRepository({
    required AppDatabase localDb,
    required SupabaseClient remoteApi,
  }) : _localDb = localDb,
       _remoteApi = remoteApi;

  Future<Database> get _db async => await _localDb.database;

  @override
  Future<List<StudentModel>> getAllStudents() async {
    final db = await _db;
    final result = await db.query('students', where: 'is_active = 1');
    return result.map((map) => StudentModel.fromMap(map)).toList();
  }

  @override
  Future<StudentModel?> getStudentById(int id) async {
    final db = await _db;
    final result = await db.query(
      'students',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return StudentModel.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<StudentModel?> getStudentByQR(String qrData) async {
    try {
      final studentId = int.parse(qrData);
      return await getStudentById(studentId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addStudent(StudentModel student) async {
    final db = await _db;
    await db.insert('students', student.toMap());
  }

  @override
  Future<void> updateStudent(StudentModel student) async {
    final db = await _db;
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  @override
  Future<void> deleteStudent(int id) async {
    final db = await _db;
    await db.update(
      'students',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<StudentModel>> searchStudents(String query) async {
    final db = await _db;
    final result = await db.query(
      'students',
      where: '(first_name LIKE ? OR last_name LIKE ?) AND is_active = 1',
      whereArgs: ['%$query%', '%$query%'],
    );
    return result.map((map) => StudentModel.fromMap(map)).toList();
  }
}
