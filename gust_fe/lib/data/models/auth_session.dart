class AuthSession {
  final int? id;
  final int userId;
  final String accessToken;
  final String? refreshToken;
  final String provider;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool biometricAllowed;

  const AuthSession({
    this.id,
    required this.userId,
    required this.accessToken,
    this.refreshToken,
    required this.provider,
    required this.createdAt,
    this.expiresAt,
    this.biometricAllowed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'provider': provider,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'biometric_allowed': biometricAllowed ? 1 : 0,
    };
  }

  factory AuthSession.fromMap(Map<String, dynamic> map) {
    return AuthSession(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String?,
      provider: map['provider'] as String? ?? 'EMAIL',
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
      biometricAllowed: (map['biometric_allowed'] as int? ?? 0) == 1,
    );
  }
}
