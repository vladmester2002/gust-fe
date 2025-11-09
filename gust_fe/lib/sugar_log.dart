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
      emotion: Emotion.values.firstWhere(
          (e) => e.name == (json['emotion'] as String).toUpperCase(),
          orElse: () => Emotion.NEUTRAL),
      location: json['location'] ?? '',
      wasCraving: json['wasCraving'] as bool,
    );
  }
}
