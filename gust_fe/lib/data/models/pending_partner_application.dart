/// Model for partner applications that are pending server submission
class PendingPartnerApplication {
  final int? id;
  final int userId;
  final String expertise;
  final String motivation;
  final String status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const PendingPartnerApplication({
    this.id,
    required this.userId,
    required this.expertise,
    required this.motivation,
    this.status = 'PENDING_SUBMISSION',
    required this.createdAt,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'expertise': expertise,
      'motivation': motivation,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory PendingPartnerApplication.fromMap(Map<String, dynamic> map) {
    return PendingPartnerApplication(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      expertise: map['expertise'] as String,
      motivation: map['motivation'] as String,
      status: map['status'] as String? ?? 'PENDING_SUBMISSION',
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null 
          ? DateTime.parse(map['synced_at'] as String)
          : null,
    );
  }

  PendingPartnerApplication copyWith({
    int? id,
    int? userId,
    String? expertise,
    String? motivation,
    String? status,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return PendingPartnerApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      expertise: expertise ?? this.expertise,
      motivation: motivation ?? this.motivation,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
