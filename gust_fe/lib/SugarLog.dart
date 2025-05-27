import 'package:gust_fe/SugarLogPage.dart';

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
}
