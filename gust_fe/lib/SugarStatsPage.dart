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
    final yesterday = dataPoints.length >= 2 ? dataPoints[dataPoints.length - 2].value : 0;
    final today = dataPoints.isNotEmpty ? dataPoints.last.value : 0;

    final diff = (today - yesterday).abs();
    final isLess = today < yesterday;
    final weeklyTotal = dataPoints.fold<int>(0, (sum, e) => sum + e.value);

    return Scaffold(
      appBar: AppBar(title: const Text("Sugar Stats")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = constraints.maxHeight * 0.5;
          final chartWidth = constraints.maxWidth * 0.8;

          return Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: chartHeight,
                  width: chartWidth,
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
                          isCurved: false, // straight lines
                          barWidth: 3,
                          color: Colors.blue,
                          belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
                          dotData: FlDotData(show: true),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isLess
                      ? "You consumed ${diff}g less than yesterday"
                      : "You consumed ${diff}g more than yesterday",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isLess ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "This week's total: ${weeklyTotal}g",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

