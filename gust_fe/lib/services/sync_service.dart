import 'dart:async';

import '../data/models/local_sugar_log.dart';
import '../repositories/partner_application_repository.dart';
import '../repositories/sugar_log_repository.dart';
import '../repositories/user_profile_repository.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;

  SyncService._internal();

  final SugarLogRepository _repository = SugarLogRepository();
  final UserProfileRepository _profileRepository = UserProfileRepository();
  final PartnerApplicationRepository _partnerRepository = PartnerApplicationRepository();
  final ApiService _api = ApiService.instance;
  bool _isSyncing = false;
  final _syncController = StreamController<bool>.broadcast();

  Stream<bool> get isSyncing => _syncController.stream;

  Future<void> syncPendingLogs(int userId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncController.add(true);

    try {
      final dirtyLogs = await _repository.fetchDirtyLogs(userId);
      if (dirtyLogs.isEmpty) {
        print('No dirty logs to sync');
      } else {
        print('Syncing ${dirtyLogs.length} pending logs...');
      }

      for (final log in dirtyLogs) {
        try {
          if (log.remoteId == null) {
            // Create new log
            final response = await _api.post('/api/sugarlogs', log.toApiMap());
            final syncedLog = LocalSugarLog.fromApi(response, userId);
            
            // Update the existing local log with remote ID and clean status
            // We preserve the local ID from the original log
            final updated = syncedLog.copyWith(id: log.id);
            await _repository.saveSyncedLog(updated);
          } else {
            // Update existing log
            final response = await _api.put('/api/sugarlogs/${log.remoteId}', log.toApiMap());
            final syncedLog = LocalSugarLog.fromApi(response, userId);
            
            // Update local log
            final updated = syncedLog.copyWith(id: log.id);
            await _repository.saveSyncedLog(updated);
          }
        } catch (e) {
          print('Failed to sync log ${log.id}: $e');
          // Keep dirty, try next time
        }
      }

      // Sync profile changes
      await syncPendingProfileChanges(userId);
      
      // Sync partner applications
      await syncPendingPartnerApplications(userId);
    } finally {
      _isSyncing = false;
      _syncController.add(false);
    }
  }

  Future<void> syncPendingProfileChanges(int userId) async {
    try {
      final dirtyProfile = await _profileRepository.fetchDirtyProfile(userId);
      if (dirtyProfile == null) {
        return;
      }

      print('Syncing profile changes for user $userId...');
      
      await _api.patch('/api/users/me/goal', {
        'goal': dirtyProfile.dailySugarGoal,
      });

      await _profileRepository.markSynced(userId);
      print('Profile changes synced successfully.');
    } catch (e) {
      print('Failed to sync profile changes: $e');
    }
  }

  Future<void> syncPendingPartnerApplications(int userId) async {
    try {
      final pendingCount = await _partnerRepository.getPendingCount(userId);
      if (pendingCount == 0) {
        return;
      }

      print('Syncing $pendingCount pending partner application(s)...');
      await _partnerRepository.syncPendingApplications(userId);
      print('Partner applications synced successfully.');
    } catch (e) {
      print('Failed to sync partner applications: $e');
    }
  }
}
