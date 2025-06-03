import 'package:flutter/material.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:intl/intl.dart';
import 'package:gust_fe/emotion.dart'; // Use the shared Emotion enum

Map<Emotion, Color> emotionColors = {
  Emotion.HAPPY: Colors.green.shade300,
  Emotion.SAD: Colors.blueGrey.shade400,
  Emotion.STRESSED: Colors.red.shade400,
  Emotion.ANXIOUS: Colors.orange.shade400,
  Emotion.TIRED: Colors.purple.shade300,
  Emotion.BORED: Colors.amber.shade300,
  Emotion.NEUTRAL: Colors.grey.shade300,
};

Map<Emotion, String> emotionEmojis = {
  Emotion.HAPPY: '😊',
  Emotion.SAD: '😢',
  Emotion.STRESSED: '😫',
  Emotion.ANXIOUS: '😰',
  Emotion.TIRED: '🥱',
  Emotion.BORED: '😑',
  Emotion.NEUTRAL: '😐',
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
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dayLogs = groupedLogs[dateKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(dateKey, style: Theme.of(context).textTheme.titleMedium),
              ),
              ...dayLogs.map((log) => SugarLogTile(log: log)),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}

class SugarLogTile extends StatelessWidget {
  final SugarLog log;
  const SugarLogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: emotionColors[log.emotion] ?? Colors.grey,
        child: Text(emotionEmojis[log.emotion] ?? "🙂"),
      ),
      title: Text(log.productName),
      subtitle: Text(
        "${log.sugarGrams}g • ${log.sugarType} • ${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')}",
      ),
      trailing: log.wasCraving
          ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
          : null,
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
