class UserProfile {
  final int? id;
  final int userId;
  final String fullName;
  final int dailySugarGoal;
  final int currentStreak;
  final DateTime? updatedAt;
  final bool isDirty;

  UserProfile({
    this.id,
    required this.userId,
    required this.fullName,
    required this.dailySugarGoal,
    required this.currentStreak,
    this.updatedAt,
    this.isDirty = false,
  });

  UserProfile copyWith({
    int? id,
    int? userId,
    String? fullName,
    int? dailySugarGoal,
    int? currentStreak,
    DateTime? updatedAt,
    bool? isDirty,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      dailySugarGoal: dailySugarGoal ?? this.dailySugarGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      updatedAt: updatedAt ?? this.updatedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'daily_sugar_goal': dailySugarGoal,
      'current_streak': currentStreak,
      'updated_at': updatedAt?.toIso8601String(),
      'is_dirty': isDirty ? 1 : 0,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      fullName: map['full_name'] as String,
      dailySugarGoal: map['daily_sugar_goal'] as int,
      currentStreak: map['current_streak'] as int,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isDirty: (map['is_dirty'] as int?) == 1,
    );
  }

  // Parse from API response (camelCase)
  factory UserProfile.fromApi(Map<String, dynamic> json, int userId) {
    return UserProfile(
      userId: userId,
      fullName: json['fullName'] as String? ?? '',
      dailySugarGoal: json['dailySugarGoal'] as int? ?? 75,
      currentStreak: json['currentStreak'] as int? ?? 0,
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }

  // Convert to API request format (camelCase)
  Map<String, dynamic> toApiMap() {
    return {
      'fullName': fullName,
      'dailySugarGoal': dailySugarGoal,
    };
  }
}
