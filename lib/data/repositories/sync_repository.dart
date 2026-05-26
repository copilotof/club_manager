// lib/data/repositories/sync_repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/repositories/i_sync_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_client.dart';

class SyncRepository implements ISyncRepository {
  final AppDatabase _localDb;
  final SupabaseClient _remoteApi;
  final Connectivity _connectivity;

  SyncRepository({
    required AppDatabase localDb,
    required SupabaseClient remoteApi,
    required Connectivity connectivity,
  }) : _localDb = localDb,
       _remoteApi = remoteApi,
       _connectivity = connectivity;

  Future<Database> get _db async => await _localDb.database;

  @override
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Future<bool> hasPendingOperations() async {
    final db = await _db;
    final result = await db.query('pending_operations', where: 'synced = 0');
    return result.isNotEmpty;
  }

  @override
  Future<void> addPendingOperation({
    required String operationType,
    required String tableName,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db;
    await db.insert('pending_operations', {
      'operation_type': operationType,
      'table_name': tableName,
      'operation': operation,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
      'synced': 0,
    });
  }

  @override
  Future<void> syncPendingOperations() async {
    final isConnected = await checkConnectivity();
    if (!isConnected) return;

    final db = await _db;
    final pending = await db.query('pending_operations', where: 'synced = 0');

    for (var op in pending) {
      try {
        // محاولة رفع العملية إلى السحابة
        // سنكمل هذا الجزء لاحقاً عند إعداد Supabase

        // إذا نجحت، نضع علامة synced = 1
        await db.update(
          'pending_operations',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [op['id']],
        );
      } catch (e) {
        // زيادة عدد المحاولات
        final newRetryCount = (op['retry_count'] as int) + 1;
        await db.update(
          'pending_operations',
          {'retry_count': newRetryCount},
          where: 'id = ?',
          whereArgs: [op['id']],
        );
      }
    }
  }
}
