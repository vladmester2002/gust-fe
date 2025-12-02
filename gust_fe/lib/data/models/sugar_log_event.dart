import '../../sugar_log.dart';

class SugarLogEvent {
  final String type;
  final SugarLog? payload;
  final int? logId;

  const SugarLogEvent({
    required this.type,
    this.payload,
    this.logId,
  });

  factory SugarLogEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return SugarLogEvent(
      type: (json['type'] ?? '').toString(),
      logId: json['logId'] as int?,
      payload: payload is Map<String, dynamic> ? SugarLog.fromJson(payload) : null,
    );
  }

  bool get isDeletion => type.toUpperCase() == 'DELETED';
}
