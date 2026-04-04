import 'dart:async';

import '../data/local/gust_database.dart';
import '../data/models/auth_session.dart';
import '../data/models/local_user.dart';
import '../services/secure_storage_service.dart';
import '../utils/hash_helper.dart';

class AuthRepository {
  AuthRepository({
    GustDatabase? database,
    SecureStorageService? storageService,
  })  : _database = database ?? GustDatabase.instance,
        _secureStorage = storageService ?? SecureStorageService.instance;

  final GustDatabase _database;
  final SecureStorageService _secureStorage;

  Future<LocalUser?> getActiveUser() async {
    final session = await _database.getActiveSession();
    if (session == null) return null;
    final user = await _database.getUserById(session.userId);
    return user;
  }

  Stream<LocalUser?> watchActiveUser() {
    return _database.watchActiveUser();
  }

  Future<LocalUser?> getUserByEmail(String email) {
    return _database.getUserByEmail(email);
  }

  Future<LocalUser?> persistUserProfile({
    required String email,
    required String fullName,
    String role = 'USER',
    String provider = 'EMAIL',
    int? remoteId,
    int? goal,
    bool? allowPartnerRequests,
    bool biometricEnabled = false,
    String? rawPassword,
    List<String>? featureFlags,
    bool emitActive = true,
  }) async {
    final existing = await _database.getUserByEmail(email);
    String? passwordHash = existing?.passwordHash;
    if (rawPassword != null && rawPassword.isNotEmpty) {
      final salt = HashHelper.generateSalt();
      passwordHash = HashHelper.hashPassword(rawPassword, salt);
    }
    final user = LocalUser(
      id: existing?.id,
      remoteId: remoteId ?? existing?.remoteId,
      email: email,
      fullName: fullName,
      role: role,
      authProvider: provider,
      passwordHash: passwordHash,
      dailySugarGoal: goal ?? existing?.dailySugarGoal,
      allowPartnerRequests:
          allowPartnerRequests ?? existing?.allowPartnerRequests ?? true,
      biometricEnabled: biometricEnabled,
      featureFlags: featureFlags ?? existing?.featureFlags ?? const [],
      lastSyncAt: DateTime.now(),
    );

    return _database.upsertUser(user, emitActive: emitActive);
  }

  Future<void> persistSession({
    required int userId,
    required String token,
    String provider = 'EMAIL',
    DateTime? expiresAt,
    bool biometricAllowed = false,
  }) async {
    final session = AuthSession(
      userId: userId,
      accessToken: token,
      provider: provider,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      biometricAllowed: biometricAllowed,
    );
    await _database.saveSession(session);
    await _secureStorage.cacheAccessToken(token);
  }

  Future<AuthSession?> readSession() => _database.getActiveSession();

  Future<void> signOut() async {
    await _database.clearSession();
    await _secureStorage.clearAccessToken();
  }

  Future<void> updatePartnerPreference(bool allow) async {
    final user = await getActiveUser();
    if (user == null || user.id == null) return;
    await _database.updatePartnerPreference(user.id!, allow);
  }

  /// Get existing guest user from local database
  Future<LocalUser?> getGuestUser() async {
    return _database.getGuestUser();
  }

  /// Save a session for a user (used for guest users)
  Future<void> saveSession({
    required int userId,
    required String provider,
    required String token,
  }) async {
    final session = AuthSession(
      userId: userId,
      accessToken: token,
      provider: provider,
      createdAt: DateTime.now(),
      biometricAllowed: false,
    );
    await _database.saveSession(session);
    await _secureStorage.cacheAccessToken(token);
  }

  Future<AuthSession?> getActiveSession() => _database.getActiveSession();

  Future<void> cacheBiometricSecret(String email, String secret) =>
      _secureStorage.cacheBiometricSecret(email, secret);

  Future<String?> readBiometricSecret(String email) =>
      _secureStorage.readBiometricSecret(email);
}
