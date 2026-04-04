import 'package:gust_fe/emotion.dart'; // <- only import from here!

class SugarLog {
  final int id;
  final int sugarGrams;
  final DateTime date;
  final int hour;
  final int minute;
  final String productName;
  final String sugarType;
  final String contextNote;
  final Emotion emotion;
  final String location;
  final bool wasCraving;
  final String visibility;

  SugarLog({
    required this.id,
    required this.sugarGrams,
    required this.date,
    required this.hour,
    required this.minute,
    required this.productName,
    required this.sugarType,
    required this.contextNote,
    required this.emotion,
    required this.location,
    required this.wasCraving,
    this.visibility = 'PRIVATE',
  });

  factory SugarLog.fromJson(Map<String, dynamic> json) {
    return SugarLog(
      id: json['id'] as int,
      sugarGrams: json['sugarGrams'] as int,
      date: DateTime.parse(json['date']),
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      productName: json['productName'] ?? '',
      sugarType: json['sugarType'] ?? '',
      contextNote: json['contextNote'] ?? '',
      emotion: _parseEmotion(json['emotion']),
      location: json['location'] ?? '',
      wasCraving: json['wasCraving'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'PRIVATE',
    );
  }

  static Emotion _parseEmotion(dynamic raw) {
    if (raw == null) {
      return Emotion.NEUTRAL;
    }
    final value = raw.toString().toUpperCase();
    return Emotion.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Emotion.NEUTRAL,
    );
  }
}
