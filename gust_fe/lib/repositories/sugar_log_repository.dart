import '../data/local/gust_database.dart';
import '../data/models/local_sugar_log.dart';
import '../services/api_service.dart';

class SugarLogRepository {
  SugarLogRepository({
    GustDatabase? database,
    ApiService? apiService,
  })  : _database = database ?? GustDatabase.instance,
        _api = apiService ?? ApiService.instance;

  final GustDatabase _database;
  final ApiService _api;

  Future<List<LocalSugarLog>> fetchLogs({
    required int userId,
    bool sharedOnly = false,
    bool forceOffline = false,
  }) async {
    // 1. Try to fetch from remote (unless forced offline)
    if (!forceOffline) {
      try {
        // CRITICAL: Check if there are any dirty (unsynced) logs first
        final dirtyLogs = await _database.fetchDirtyLogs(userId);
        
        // Only fetch remote if not looking for shared-only (unless we add that filter to API)
        // For now, let's assume we sync all logs
        final List<dynamic> remoteLogs = await _api.get('/api/sugarlogs');
        
        // 2. Update local cache
        final logs = remoteLogs.map((json) => LocalSugarLog.fromApi(json, userId)).toList();
        
        // CRITICAL FIX: If there are dirty logs, merge them instead of replacing
        if (dirtyLogs.isNotEmpty) {
          print('Found ${dirtyLogs.length} dirty logs - merging with remote data instead of replacing');
          
          // Update each remote log individually (upsert by remoteId)
          for (final remoteLog in logs) {
            await _database.upsertRemoteLog(remoteLog);
          }
          
          // Dirty logs are preserved and will be synced later
        } else {
          // No dirty logs, safe to replace
          await _database.replaceLogs(userId, logs);
        }
        
        // 3. Return updated local data (includes both synced and dirty logs)
        return _database.fetchLogs(userId: userId, sharedOnly: sharedOnly);
      } catch (e) {
        // 4. Fallback to local cache on error (Offline Mode)
        print('Offline mode: Fetching logs from local DB ($e)');
        return _database.fetchLogs(userId: userId, sharedOnly: sharedOnly);
      }
    } else {
      // Forced offline (e.g. guest user)
      return _database.fetchLogs(userId: userId, sharedOnly: sharedOnly);
    }
  }

  Stream<List<LocalSugarLog>> watchLogs(int userId) {
    return _database.watchLogs(userId);
  }

  Future<List<LocalSugarLog>> fetchDirtyLogs(int userId) {
    return _database.fetchDirtyLogs(userId);
  }

  Future<int> addLog(LocalSugarLog log) async {
    try {
      // 1. Try to create on remote
      final response = await _api.post('/api/sugarlogs', log.toApiMap());
      
      // 2. If success, save to local DB as synced
      final syncedLog = LocalSugarLog.fromApi(response, log.userId);
      return _database.insertSugarLog(syncedLog);
    } catch (e) {
      // 3. If offline, save to local DB as dirty (to be synced later)
      print('Offline mode: Saving log locally ($e)');
      return _database.insertSugarLog(log.copyWith(isDirty: true));
    }
  }

  Future<void> updateLog(LocalSugarLog log) async {
    try {
      // 1. Try to update on remote
      // We need the remote ID to update on server. If it's missing (created offline), we can't update yet.
      if (log.remoteId != null) {
        final response = await _api.put('/api/sugarlogs/${log.remoteId}', log.toApiMap());
        
        // 2. If success, update local DB as synced
        final syncedLog = LocalSugarLog.fromApi(response, log.userId);
        await _database.updateSugarLog(syncedLog);
      } else {
        // If no remote ID, it's a local-only log. Just update locally.
        // The sync worker will handle creating it on server later.
        await _database.updateSugarLog(log.copyWith(isDirty: true));
      }
    } catch (e) {
      // 3. If offline, update local DB as dirty
      print('Offline mode: Updating log locally ($e)');
      await _database.updateSugarLog(log.copyWith(isDirty: true));
    }
  }

  Future<void> replaceFromRemote(int userId, List<LocalSugarLog> logs) {
    return _database.replaceLogs(userId, logs);
  }

  Future<void> deleteLog(int logId, int userId) async {
    try {
      // Get the log to find its remote ID
      final logs = await _database.fetchLogs(userId: userId);
      final log = logs.firstWhere(
        (l) => l.id == logId, 
        orElse: () => throw Exception('Log not found'),
      );
      
      // Try to delete from server if it has a remote ID
      if (log.remoteId != null) {
        try {
          await _api.delete('/api/sugarlogs/${log.remoteId}');
          print('Deleted log ${log.remoteId} from server');
        } catch (e) {
          print('Could not delete from server (offline?): $e');
          // Continue to delete locally anyway
        }
      }
      
      // Always delete locally
      await _database.deleteLog(logId, userId);
      print('Deleted log $logId locally');
    } catch (e) {
      // If we can't find the log, try to delete by ID anyway
      print('Error during delete, attempting direct deletion: $e');
      try {
        await _database.deleteLog(logId, userId);
      } catch (e2) {
        print('Failed to delete log: $e2');
        rethrow;
      }
    }
  }

  Future<void> saveSyncedLog(LocalSugarLog log) {
    // Directly update the database without triggering API calls
    // This is used by SyncService to mark logs as clean after syncing
    return _database.updateSugarLog(log.copyWith(isDirty: false, syncedAt: DateTime.now()));
  }

  Future<void> markSynced(List<int> ids) {
    return _database.markLogsSynced(ids);
  }

  Future<void> upsertRemoteLog(LocalSugarLog log) {
    return _database.upsertRemoteLog(log);
  }

  Future<void> deleteByRemoteId(int remoteId, int userId) {
    return _database.deleteLogByRemoteId(remoteId, userId);
  }
}
