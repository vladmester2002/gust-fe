import 'package:flutter/material.dart';
import 'package:gust_fe/SugarLog.dart';

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


class SugarLogPage extends StatelessWidget {
  final List<SugarLog> logs;

  const SugarLogPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final groupedLogs = <String, List<SugarLog>>{};

    for (var log in logs) {
      final key = "${log.date.year}-${log.date.month}-${log.date.day}";
      groupedLogs.putIfAbsent(key, () => []).add(log);
    }

    final sortedKeys = groupedLogs.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Scaffold(
      appBar: AppBar(title: const Text('Sugar Logs')),
      body: ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, dateIndex) {
          final key = sortedKeys[dateIndex];
          final dailyLogs = groupedLogs[key]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  key,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...dailyLogs.map((log) => _buildLogTile(log)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogTile(SugarLog log) {
    final color = emotionColors[log.emotion] ?? Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              title: Text(
              log.productName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
              subtitle: Text(
                '${log.sugarGrams}g at ${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')} – ${log.sugarType}\n${log.contextNote}\nMood: ${log.emotion.name.toUpperCase()} ${log.wasCraving ? "(Craving)" : ""}',
              ),
              isThreeLine: true,
            ),
          ),
          Container(
            width: 10,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
