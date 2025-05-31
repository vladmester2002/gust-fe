import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:intl/intl.dart';

class SugarStatsPage extends StatelessWidget {
  final List<SugarLog> logs;

  const SugarStatsPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past7Days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - i),
    ).reversed.toList();

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

    final weeklyGoal = 210; // e.g., 30g/day * 7 days
    final percentOfGoal = (weeklyTotal / weeklyGoal).clamp(0.0, 1.0);

    // For responsiveness
    final chartHeight = MediaQuery.of(context).size.height * 0.33;
    final chartWidth = MediaQuery.of(context).size.width * 0.96;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sugar Stats"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
              child: Column(
                children: [
                  // --- LINE CHART ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: SizedBox(
                        height: chartHeight,
                        width: chartWidth,
                        child: dataPoints.isEmpty
                            ? Center(child: Text("No data to show.", style: TextStyle(color: Colors.grey)))
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 10,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: Colors.grey.withOpacity(0.13),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget: (value, _) {
                                          int idx = value.toInt();
                                          if (idx < 0 || idx >= dataPoints.length) return const SizedBox();
                                          final date = dataPoints[idx].key;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 5),
                                            child: Text(
                                              DateFormat('E').format(date), // Sun, Mon, etc.
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 38,
                                        getTitlesWidget: (value, _) => Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text('${value.toInt()}g', style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor.withOpacity(0.25),
                                    ),
                                  ),
                                  minY: 0,
                                  maxY: (dailyTotals.values.reduce((a, b) => a > b ? a : b) + 10).toDouble(),
                                  clipData: FlClipData.all(),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: [
                                        for (int i = 0; i < dataPoints.length; i++)
                                          FlSpot(i.toDouble(), dataPoints[i].value.toDouble())
                                      ],
                                      isCurved: false,
                                      barWidth: 4,
                                      color: Colors.deepPurple,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.deepPurple.withOpacity(0.18),
                                      ),
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                          radius: 5,
                                          color: Colors.deepPurpleAccent,
                                          strokeWidth: 0,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // --- DAY-TO-DAY SUMMARY CARD ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    color: isLess ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            isLess ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isLess ? Colors.green : Colors.red,
                            size: 36,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Text(
                              isLess
                                  ? "You consumed $diff grams less sugar than yesterday"
                                  : "You consumed $diff grams more sugar than yesterday",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isLess ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- WEEKLY TOTAL AND PROGRESS ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cake_rounded, color: Colors.pink.shade300, size: 30),
                              const SizedBox(width: 12),
                              Text(
                                "This week's total:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$weeklyTotal g',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: percentOfGoal,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: percentOfGoal < 0.8
                                ? Colors.green
                                : (percentOfGoal < 1.1 ? Colors.orange : Colors.red),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          const SizedBox(height: 7),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Goal: $weeklyGoal g',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
