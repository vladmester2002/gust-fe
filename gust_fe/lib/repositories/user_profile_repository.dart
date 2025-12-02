import '../data/local/gust_database.dart';
import '../data/models/user_profile.dart';
import '../services/api_service.dart';

class UserProfileRepository {
  UserProfileRepository({
    GustDatabase? database,
    ApiService? apiService,
  })  : _database = database ?? GustDatabase.instance,
        _api = apiService ?? ApiService.instance;

  final GustDatabase _database;
  final ApiService _api;

  /// Fetch user profile with offline-first pattern
  /// 1. Try API -> Update cache -> Return
  /// 2. On error, return cached data
  Future<UserProfile?> fetchProfile(int userId) async {
    try {
      // Fetch from API
      final response = await _api.get('/api/users/me/profile');
      
      // Parse and cache
      final profile = UserProfile.fromApi(response as Map<String, dynamic>, userId);
      await _database.upsertUserProfile(profile);
      
      return profile;
    } catch (e) {
      // Fallback to cache
      print('Offline mode: Fetching profile from local cache ($e)');
      return _database.fetchUserProfile(userId);
    }
  }

  /// Fetch user streak with offline-first pattern
  Future<int> fetchStreak(int userId) async {
    try {
      // Fetch from API
      final response = await _api.get('/api/users/me/streak');
      final streak = (response as Map<String, dynamic>)['days'] as int? ?? 0;
      
      // Update cached profile with new streak
      final cachedProfile = await _database.fetchUserProfile(userId);
      if (cachedProfile != null) {
        await _database.upsertUserProfile(
          cachedProfile.copyWith(currentStreak: streak, updatedAt: DateTime.now()),
        );
      }
      
      return streak;
    } catch (e) {
      // Fallback to cache
      print('Offline mode: Fetching streak from local cache ($e)');
      final cachedProfile = await _database.fetchUserProfile(userId);
      return cachedProfile?.currentStreak ?? 0;
    }
  }

  /// Update daily goal with write-through cache
  /// 1. Try API -> Update cache as synced
  /// 2. On error, update cache as dirty
  Future<bool> updateDailyGoal(int userId, int goal) async {
    try {
      // Try to update on remote
      await _api.patch('/api/users/me/goal', {'goal': goal});
      
      // Success, update cache as synced
      await _database.updateUserProfileGoal(userId, goal, isDirty: false);
      return true;
    } catch (e) {
      // Offline, update cache as dirty
      print('Offline mode: Saving goal update locally ($e)');
      await _database.updateUserProfileGoal(userId, goal, isDirty: true);
      return false; // Indicate not synced yet
    }
  }

  /// Get dirty profile for sync
  Future<UserProfile?> fetchDirtyProfile(int userId) {
    return _database.fetchDirtyUserProfile(userId);
  }

  /// Mark profile as synced (called by SyncService)
  Future<void> markSynced(int userId) {
    return _database.markUserProfileSynced(userId);
  }
}
