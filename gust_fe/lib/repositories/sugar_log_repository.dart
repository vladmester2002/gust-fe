import '../data/local/gust_database.dart';
import '../data/models/local_sugar_log.dart';

class SugarLogRepository {
  SugarLogRepository({GustDatabase? database})
      : _database = database ?? GustDatabase.instance;

  final GustDatabase _database;

  Future<List<LocalSugarLog>> fetchLogs({
    required int userId,
    bool sharedOnly = false,
  }) {
    return _database.fetchLogs(userId: userId, sharedOnly: sharedOnly);
  }

  Stream<List<LocalSugarLog>> watchLogs(int userId) {
    return _database.watchLogs(userId);
  }

  Future<int> addLog(LocalSugarLog log) {
    return _database.insertSugarLog(log);
  }

  Future<void> updateLog(LocalSugarLog log) {
    return _database.updateSugarLog(log);
  }

  Future<void> replaceFromRemote(int userId, List<LocalSugarLog> logs) {
    return _database.replaceLogs(userId, logs);
  }

  Future<void> deleteLog(int logId, int userId) {
    return _database.deleteLog(logId, userId);
  }

  Future<void> markSynced(List<int> ids) {
    return _database.markLogsSynced(ids);
  }
}
