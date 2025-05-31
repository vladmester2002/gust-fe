import 'package:flutter/material.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:intl/intl.dart';

enum Emotion {
  happy,
  sad,
  stressed,
  anxious,
  tired,
  bored,
  neutral,
}

Map<Emotion, Color> emotionColors = {
  Emotion.happy: Colors.green.shade300,
  Emotion.sad: Colors.blueGrey.shade400,
  Emotion.stressed: Colors.red.shade400,
  Emotion.anxious: Colors.orange.shade400,
  Emotion.tired: Colors.purple.shade300,
  Emotion.bored: Colors.amber.shade300,
  Emotion.neutral: Colors.grey.shade300,
};

Map<Emotion, String> emotionEmojis = {
  Emotion.happy: '😊',
  Emotion.sad: '😢',
  Emotion.stressed: '😫',
  Emotion.anxious: '😰',
  Emotion.tired: '🥱',
  Emotion.bored: '😑',
  Emotion.neutral: '😐',
};

class SugarLogPage extends StatelessWidget {
  final List<SugarLog> logs;

  const SugarLogPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final groupedLogs = <String, List<SugarLog>>{};
    for (var log in logs) {
      final key = DateFormat.yMMMMd().format(log.date);
      groupedLogs.putIfAbsent(key, () => []).add(log);
    }
    final sortedKeys = groupedLogs.keys.toList()
      ..sort((a, b) => DateFormat.yMMMMd().parse(b).compareTo(DateFormat.yMMMMd().parse(a)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugar Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: sortedKeys.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, dateIndex) {
          final key = sortedKeys[dateIndex];
          final dailyLogs = groupedLogs[key]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              // Log cards
              ...dailyLogs.map((log) => _buildLogTile(context, log)).toList(),
              if (dateIndex < sortedKeys.length - 1)
                const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, SugarLog log) {
    final color = emotionColors[log.emotion] ?? Colors.grey.shade200;
    final emoji = emotionEmojis[log.emotion] ?? '';
    final timeStr =
        '${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    log.emotion.name[0].toUpperCase() + log.emotion.name.substring(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color.darken(0.18),
                    ),
                  ),
                ],
              ),
            ),
            if (log.wasCraving)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.whatshot, color: Colors.red.shade300, size: 18),
              ),
          ],
        ),
        title: Text(
          log.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cake_outlined, size: 17, color: Colors.pinkAccent),
                  const SizedBox(width: 4),
                  Text('${log.sugarGrams}g', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 14),
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text(timeStr, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 14),
                  Icon(Icons.label_outline, size: 15, color: Colors.teal),
                  const SizedBox(width: 2),
                  Text(log.sugarType, style: const TextStyle(fontSize: 14)),
                ],
              ),
              if (log.contextNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment_outlined, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          log.contextNote,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (log.location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, size: 15, color: Colors.lightBlue.shade400),
                      const SizedBox(width: 4),
                      Text(log.location, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: Container(
          width: 10,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

extension ColorBrightness on Color {
  /// Returns a [Color] that is a darkened version of this color.
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
