import 'package:flutter/material.dart';
import 'package:gust_fe/SugarLog.dart';

class SugarLogPage extends StatelessWidget {
  final List<SugarLog> logs;

  const SugarLogPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sugar Logs')),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(log.productName),
              subtitle: Text(
                  '${log.sugarGrams}g at ${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')} – ${log.sugarType}\n${log.contextNote}\nMood: ${log.emotion} ${log.wasCraving ? "(Craving)" : ""}'),
              trailing: Text('${log.date.month}/${log.date.day}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
