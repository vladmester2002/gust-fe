import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gust_fe/SugarLog.dart';

class SugarStatsPage extends StatelessWidget {
  final List<SugarLog> logs;

  const SugarStatsPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past7Days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - i)).reversed.toList();

    final Map<DateTime, int> dailyTotals = {
      for (var day in past7Days) day: 0,
    };

    for (final log in logs) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      if (dailyTotals.containsKey(date)) {
        dailyTotals[date] = dailyTotals[date]! + log.sugarGrams;
      }
    }

    final dataPoints = dailyTotals.entries.toList();
    final yesterday = dataPoints[dataPoints.length - 2].value;
    final today = dataPoints.last.value;

    final diff = (today - yesterday).abs();
    final isLess = today < yesterday;

    return Scaffold(
      appBar: AppBar(title: const Text("Sugar Stats")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              isLess
                  ? "You consumed $diff less than yesterday"
                  : "You consumed $diff more than yesterday",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isLess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          int index = value.toInt();
                          if (index < 0 || index >= dataPoints.length) return const SizedBox();
                          final date = dataPoints[index].key;
                          return Text("${date.month}/${date.day}", style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < dataPoints.length; i++)
                          FlSpot(i.toDouble(), dataPoints[i].value.toDouble())
                      ],
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.blue,
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
                      dotData: FlDotData(show: true),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
