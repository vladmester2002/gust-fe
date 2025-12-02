import '../data/local/gust_database.dart';
import '../data/models/pending_partner_application.dart';
import '../services/partner_access_api.dart';

/// Repository for managing partner applications with offline support
class PartnerApplicationRepository {
  PartnerApplicationRepository({
    GustDatabase? database,
    PartnerAccessApi? api,
  })  : _database = database ?? GustDatabase.instance,
        _api = api ?? const PartnerAccessApi();

  final GustDatabase _database;
  final PartnerAccessApi _api;

  /// Queue a partner application for offline submission
  Future<int> queueApplication({
    required String expertise,
    required String motivation,
    required int userId,
  }) async {
    return await _database.insertPendingPartnerApplication(
      userId: userId,
      expertise: expertise,
      motivation: motivation,
    );
  }

  /// Check if user has pending applications
  Future<bool> hasPendingApplications(int userId) async {
    final pending = await _database.fetchPendingPartnerApplications(userId);
    return pending.isNotEmpty;
  }

  /// Get count of pending applications
  Future<int> getPendingCount(int userId) async {
    final pending = await _database.fetchPendingPartnerApplications(userId);
    return pending.length;
  }

  /// Sync all pending applications to server
  Future<void> syncPendingApplications(int userId) async {
    final pending = await _database.fetchPendingPartnerApplications(userId);
    
    if (pending.isEmpty) return;

    print('Syncing ${pending.length} pending partner application(s)...');

    for (final app in pending) {
      try {
        await _api.applyForPartnerRole(
          expertise: app.expertise,
          motivation: app.motivation,
        );
        
        await _database.markPartnerApplicationSynced(app.id!);
        print('Partner application ${app.id} synced successfully');
      } catch (e) {
        print('Failed to sync partner application ${app.id}: $e');
        // Keep it pending for next sync attempt
      }
    }
  }

  /// Delete a pending application (if user wants to cancel)
  Future<void> deletePendingApplication(int appId) async {
    await _database.deletePendingPartnerApplication(appId);
  }

  /// Get all pending applications for display
  Future<List<PendingPartnerApplication>> getPendingApplications(int userId) async {
    return await _database.fetchPendingPartnerApplications(userId);
  }
}
