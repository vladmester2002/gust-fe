class LocalSugarLog {
  final int? id;
  final int? remoteId;
  final int userId;
  final int sugarGrams;
  final DateTime date;
  final int hour;
  final int minute;
  final String? productName;
  final String? sugarType;
  final String? contextNote;
  final String emotion;
  final String? location;
  final bool wasCraving;
  final String visibility;
  final bool isDirty;
  final DateTime? syncedAt;

  const LocalSugarLog({
    this.id,
    this.remoteId,
    required this.userId,
    required this.sugarGrams,
    required this.date,
    required this.hour,
    required this.minute,
    this.productName,
    this.sugarType,
    this.contextNote,
    this.emotion = 'NEUTRAL',
    this.location,
    this.wasCraving = false,
    this.visibility = 'PRIVATE',
    this.isDirty = true,
    this.syncedAt,
  });

  LocalSugarLog copyWith({
    int? id,
    int? remoteId,
    int? userId,
    int? sugarGrams,
    DateTime? date,
    int? hour,
    int? minute,
    String? productName,
    String? sugarType,
    String? contextNote,
    String? emotion,
    String? location,
    bool? wasCraving,
    String? visibility,
    bool? isDirty,
    DateTime? syncedAt,
  }) {
    return LocalSugarLog(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      userId: userId ?? this.userId,
      sugarGrams: sugarGrams ?? this.sugarGrams,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      productName: productName ?? this.productName,
      sugarType: sugarType ?? this.sugarType,
      contextNote: contextNote ?? this.contextNote,
      emotion: emotion ?? this.emotion,
      location: location ?? this.location,
      wasCraving: wasCraving ?? this.wasCraving,
      visibility: visibility ?? this.visibility,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'user_id': userId,
      'sugar_grams': sugarGrams,
      'date': date.toIso8601String(),
      'hour': hour,
      'minute': minute,
      'product_name': productName,
      'sugar_type': sugarType,
      'context_note': contextNote,
      'emotion': emotion,
      'location': location,
      'was_craving': wasCraving ? 1 : 0,
      'visibility': visibility,
      'is_dirty': isDirty ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory LocalSugarLog.fromMap(Map<String, dynamic> map) {
    return LocalSugarLog(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      userId: map['user_id'] as int,
      sugarGrams: map['sugar_grams'] as int,
      date: DateTime.parse(map['date'] as String),
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      productName: map['product_name'] as String?,
      sugarType: map['sugar_type'] as String?,
      contextNote: map['context_note'] as String?,
      emotion: map['emotion'] as String? ?? 'NEUTRAL',
      location: map['location'] as String?,
      wasCraving: (map['was_craving'] as int? ?? 0) == 1,
      visibility: map['visibility'] as String? ?? 'PRIVATE',
      isDirty: (map['is_dirty'] as int? ?? 0) == 1,
      syncedAt: map['synced_at'] != null
          ? DateTime.tryParse(map['synced_at'] as String)
          : null,
    );
  }
}
