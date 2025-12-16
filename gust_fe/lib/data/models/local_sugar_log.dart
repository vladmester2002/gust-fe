import '../../utils/input_sanitizer.dart';

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

  /// Converts to database map with sanitized string values.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'user_id': userId,
      'sugar_grams': sugarGrams.clamp(0, 9999),
      'date': date.toIso8601String(),
      'hour': hour.clamp(0, 23),
      'minute': minute.clamp(0, 59),
      'product_name': InputSanitizer.sanitizeProductName(productName),
      'sugar_type': InputSanitizer.sanitizeText(sugarType, maxLength: 100),
      'context_note': InputSanitizer.sanitizeNotes(contextNote),
      'emotion': InputSanitizer.sanitizeText(emotion, maxLength: 20),
      'location': InputSanitizer.sanitizeText(location, maxLength: 200),
      'was_craving': wasCraving ? 1 : 0,
      'visibility': InputSanitizer.sanitizeText(visibility, maxLength: 30),
      'is_dirty': isDirty ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Converts to API request map with sanitized string values.
  Map<String, dynamic> toApiMap() {
    return {
      // ID is not sent for creation, but might be needed for updates if backend requires it in body
      // 'id': remoteId, 
      'sugarGrams': sugarGrams.clamp(0, 9999),
      'date': date.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'hour': hour.clamp(0, 23),
      'minute': minute.clamp(0, 59),
      'productName': InputSanitizer.sanitizeProductName(productName),
      'sugarType': InputSanitizer.sanitizeText(sugarType, maxLength: 100),
      'contextNote': InputSanitizer.sanitizeNotes(contextNote),
      'emotion': InputSanitizer.sanitizeText(emotion, maxLength: 20),
      'location': InputSanitizer.sanitizeText(location, maxLength: 200),
      'wasCraving': wasCraving,
      'visibility': InputSanitizer.sanitizeText(visibility, maxLength: 30),
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

  factory LocalSugarLog.fromApi(Map<String, dynamic> map, int currentUserId) {
    return LocalSugarLog(
      remoteId: map['id'] as int?, // API ID becomes remoteId
      userId: currentUserId, // We need to pass this in as API might not return it or returns ownerId
      sugarGrams: map['sugarGrams'] as int,
      date: DateTime.parse(map['date'] as String),
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      productName: map['productName'] as String?,
      sugarType: map['sugarType'] as String?,
      contextNote: map['contextNote'] as String?,
      emotion: map['emotion'] as String? ?? 'NEUTRAL',
      location: map['location'] as String?,
      wasCraving: map['wasCraving'] as bool? ?? false,
      visibility: map['visibility'] as String? ?? 'PRIVATE',
      isDirty: false, // Data from API is clean
      syncedAt: DateTime.now(),
    );
  }
}
