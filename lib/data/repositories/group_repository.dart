// lib/data/repositories/group_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/group_model.dart';
import '../models/session_model.dart';
import '../datasources/local/app_database.dart';

class GroupRepository {
  final AppDatabase _localDb;

  GroupRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  Future<List<GroupModel>> getGroupsByHall(int hallId) async {
    final db = await _db;
    final result = await db.query(
      'groups',
      where: 'hall_id = ?',
      whereArgs: [hallId],
      orderBy: 'name',
    );
    return result.map((map) => GroupModel.fromMap(map)).toList();
  }

  Future<List<GroupModel>> getAllGroups() async {
    final db = await _db;
    final result = await db.query('groups', orderBy: 'name');
    return result.map((map) => GroupModel.fromMap(map)).toList();
  }

  Future<int> addGroup(GroupModel group) async {
    final db = await _db;
    return await db.insert('groups', group.toMap());
  }

  Future<int> updateGroup(GroupModel group) async {
    final db = await _db;
    return await db.update(
      'groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<int> deleteGroup(int id) async {
    final db = await _db;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // إدارة الحصص
  Future<List<SessionModel>> getSessionsByGroup(int groupId) async {
    final db = await _db;
    final result = await db.query(
      'sessions',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'day_of_week',
    );
    return result.map((map) => SessionModel.fromMap(map)).toList();
  }

  Future<int> addSession(SessionModel session) async {
    final db = await _db;
    return await db.insert('sessions', session.toMap());
  }

  Future<int> deleteSession(int id) async {
    final db = await _db;
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }
}
