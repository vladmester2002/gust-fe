import 'dart:convert';

class LocalUser {
  final int? id;
  final int? remoteId;
  final String email;
  final String fullName;
  final String role;
  final String authProvider;
  final String? passwordHash;
  final int? dailySugarGoal;
  final List<String> featureFlags;
  final bool allowPartnerRequests;
  final bool biometricEnabled;
  final DateTime? lastSyncAt;

  const LocalUser({
    this.id,
    this.remoteId,
    required this.email,
    required this.fullName,
    this.role = 'USER',
    this.authProvider = 'EMAIL',
    this.passwordHash,
    this.dailySugarGoal,
    this.featureFlags = const [],
    this.allowPartnerRequests = true,
    this.biometricEnabled = false,
    this.lastSyncAt,
  });

  LocalUser copyWith({
    int? id,
    int? remoteId,
    String? email,
    String? fullName,
    String? role,
    int? dailySugarGoal,
    String? authProvider,
    String? passwordHash,
    bool? allowPartnerRequests,
    List<String>? featureFlags,
    bool? biometricEnabled,
    DateTime? lastSyncAt,
  }) {
    return LocalUser(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      passwordHash: passwordHash ?? this.passwordHash,
      dailySugarGoal: dailySugarGoal ?? this.dailySugarGoal,
      featureFlags: featureFlags ?? this.featureFlags,
      allowPartnerRequests: allowPartnerRequests ?? this.allowPartnerRequests,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'email': email,
      'full_name': fullName,
      'role': role,
      'auth_provider': authProvider,
      'password_hash': passwordHash,
      'daily_sugar_goal': dailySugarGoal,
      'feature_flags': jsonEncode(featureFlags),
      'allow_partner_requests': allowPartnerRequests ? 1 : 0,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String? ?? 'USER',
      authProvider: map['auth_provider'] as String? ?? 'EMAIL',
      passwordHash: map['password_hash'] as String?,
      dailySugarGoal: map['daily_sugar_goal'] as int?,
      featureFlags: _decodeFeatures(map['feature_flags']),
      allowPartnerRequests: (map['allow_partner_requests'] as int? ?? 1) == 1,
      biometricEnabled: (map['biometric_enabled'] as int? ?? 0) == 1,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.tryParse(map['last_sync_at'] as String)
          : null,
    );
  }
}

List<String> _decodeFeatures(dynamic value) {
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
  }
  return const [];
}
