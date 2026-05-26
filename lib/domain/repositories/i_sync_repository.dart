// lib/domain/repositories/i_sync_repository.dart
abstract class ISyncRepository {
  Future<bool> checkConnectivity();
  Future<bool> hasPendingOperations();
  Future<void> syncPendingOperations();
  Future<void> addPendingOperation({
    required String operationType,
    required String tableName,
    required String operation,
    required Map<String, dynamic> data,
  });
}
