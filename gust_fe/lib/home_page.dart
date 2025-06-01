import 'dart:convert';
import 'dart:math'; // <--- NEW for max()
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:gust_fe/SugarLog.dart';
import 'package:intl/intl.dart';
import 'emotion.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sugar_log_creation_dialog.dart';
import 'package:another_flushbar/flushbar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.logs});
  final List<SugarLog> logs;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SugarLog> _logs = [];
  bool _loading = false;
  String? _fullName;
  int _dailyGoal = 75;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _logs = List.from(widget.logs);
    _loadUserProfile();
    _loadUserStreak();
    _fetchLogs();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _showFlushBar({
    required String message,
    required Color color,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) async {
    await Flushbar<void>(
      message: message,
      duration: duration,
      backgroundColor: color,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: icon != null ? Icon(icon, color: Colors.white) : null,
    ).show(context);
  }

  Future<void> _loadUserProfile() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final url = Uri.parse('$baseUrl/api/users/me/profile');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _fullName = data['fullName'] ?? "User";
          _dailyGoal = data['dailySugarGoal'] ?? 75;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadUserStreak() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final url = Uri.parse('$baseUrl/api/users/me/streak');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _streak = data['days'] ?? 0;
        });
      }
    } catch (e) {}
  }

  Future<void> _updateDailyGoalDialog() async {
    int? newGoal = _dailyGoal;
    final controller = TextEditingController(text: _dailyGoal.toString());
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Set Daily Sugar Goal"),
          content: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Goal (grams per day)",
            ),
            validator: (v) {
              final val = int.tryParse(v ?? '');
              if (val == null || val < 1) return "Enter a positive number";
              return null;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final parsed = int.tryParse(controller.text);
                if (parsed != null && parsed > 0) {
                  newGoal = parsed;
                  final token = await _getToken();
                  if (token != null) {
                    final url = Uri.parse('$baseUrl/api/users/me/goal');
                    final resp = await http.patch(url,
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: jsonEncode({'goal': newGoal}));
                    if (resp.statusCode == 200) {
                      setState(() => _dailyGoal = newGoal!);
                      Navigator.pop(ctx);
                      await _showFlushBar(
                        message: "Daily goal updated!",
                        color: Colors.green,
                        icon: Icons.check_circle,
                      );
                    } else {
                      await _showFlushBar(
                        message: "Failed to update goal: ${resp.body}",
                        color: Colors.red,
                        icon: Icons.error,
                      );
                    }
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final token = await _getToken();
    if (token == null) {
      setState(() => _loading = false);
      await _showFlushBar(
        message: 'Not logged in. Please login again.',
        color: Colors.red,
        icon: Icons.error,
      );
      return;
    }
    try {
      final url = Uri.parse('$baseUrl/api/sugarlogs');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _logs = data.map((e) => SugarLog.fromJson(e)).toList();
        });
      } else {
        await _showFlushBar(
          message: 'Could not load logs: ${response.statusCode}',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      await _showFlushBar(
        message: 'Error loading logs: $e',
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showRegisterModal({SugarLog? editLog}) async {
    await showDialog(
      context: context,
      builder: (context) => SugarLogCreationDialog(
        existingLog: editLog,
        onCreated: (log) async {
          setState(() {
            _logs.add(log);
          });
          _loadUserStreak();
          await _fetchLogs();
        },
        onUpdated: (log) {
          setState(() {
            final idx = _logs.indexWhere((l) => l.id == log.id);
            if (idx != -1) _logs[idx] = log;
          });
          _loadUserStreak();
        },
        onDeleted: (log) {
          setState(() {
            _logs.removeWhere((l) => l.id == log.id);
          });
          _loadUserStreak();
        },
      ),
    );
    _loadUserStreak();
    await _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayLogs = _logs.where((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day).toList();

    final todaySugar = todayLogs.fold<int>(0, (sum, log) => sum + log.sugarGrams);

    final past7Days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final Map<DateTime, int> dailyTotals = {
      for (var day in past7Days) day: 0,
    };
    for (final log in _logs) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      if (dailyTotals.containsKey(date)) {
        dailyTotals[date] = dailyTotals[date]! + log.sugarGrams;
      }
    }
    final dataPoints = dailyTotals.entries.toList();

    // --- Fix maxY to be a round, clean number (like 10, 20, 30, 40)
    double maxValue = dataPoints.map((e) => e.value).isNotEmpty
        ? dataPoints.map((e) => e.value).reduce(max).toDouble()
        : 10;
    double maxY = maxValue <= 10
        ? 10
        : ((maxValue + 9) ~/ 10) * 10;
    // if all zeros, show at least 10

    final dailyGoal = _dailyGoal;
    final remaining = (dailyGoal - todaySugar).clamp(0, dailyGoal);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('GUST Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchLogs();
              _loadUserStreak();
              _loadUserProfile();
            },
            tooltip: "Reload logs",
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        child: Icon(Icons.person, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back,', style: theme.textTheme.bodySmall),
                            Text(
                              _fullName ?? 'GUST User',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$_streak',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "day${_streak == 1 ? '' : 's'}",
                              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.coffee, color: theme.colorScheme.primary, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Today's Sugar Intake",
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$todaySugar g / $dailyGoal g",
                                      style: TextStyle(
                                          fontSize: 17,
                                          color: todaySugar > dailyGoal ? Colors.red : Colors.green,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Icon(todaySugar > dailyGoal ? Icons.warning_amber : Icons.check_circle,
                                      color: todaySugar > dailyGoal ? Colors.red : Colors.green),
                                  Text(
                                    todaySugar > dailyGoal ? "Over" : "Good",
                                    style: TextStyle(
                                        color: todaySugar > dailyGoal ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (todaySugar / dailyGoal).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade300,
                            color: todaySugar > dailyGoal
                                ? Colors.red
                                : (todaySugar > dailyGoal * 0.7 ? Colors.orange : Colors.green),
                            minHeight: 9,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text("Remaining: $remaining g",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: todaySugar > dailyGoal ? Colors.red : Colors.grey.shade800)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.show_chart, color: theme.colorScheme.primary, size: 28),
                              const SizedBox(width: 8),
                              Text("Sugar Trends (7 Days)", style: theme.textTheme.titleMedium),
                            ],
                          ),
                          SizedBox(
                            height: 180,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: maxY.toDouble(),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 10,
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
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 12)),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 36, // a bit more space
                                      getTitlesWidget: (value, meta) {
                                        // only show integer ticks (0, 10, 20, 30, 40, ...)
                                        if (value % 10 == 0) {
                                          return Text('${value.toInt()}g', style: const TextStyle(fontSize: 13));
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
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
                                      color: Colors.deepPurple.withOpacity(0.13),
                                    ),
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.deepPurple,
                                        strokeWidth: 0,
                                      ),
                                    ),
                                  ),
                                ],
                                // --------------- TOOLTIP SECTION ---------------
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  handleBuiltInTouches: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipBgColor: Colors.white,
                                    tooltipRoundedRadius: 10,
                                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    tooltipBorder: BorderSide(color: Colors.deepPurple.shade100, width: 1.5),
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((touchedSpot) {
                                        final idx = touchedSpot.spotIndex;
                                        final dayName = DateFormat('EEEE').format(dataPoints[idx].key);
                                        final value = dataPoints[idx].value;
                                        return LineTooltipItem(
                                          "$dayName\n",
                                          const TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            height: 1.3,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "$value g",
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                height: 1.6,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                // --------------- END TOOLTIP SECTION ---------------
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.fastfood, color: theme.colorScheme.primary, size: 26),
                              const SizedBox(width: 6),
                              Text("Today's Foods", style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          todayLogs.isEmpty
                              ? Text("No entries yet. Start tracking your sugar today!",
                                  style: TextStyle(color: Colors.grey.shade600))
                              : Column(
                                  children: [
                                    for (var log in todayLogs)
                                      GestureDetector(
                                        onTap: () => _showRegisterModal(editLog: log),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.circle, size: 11, color: theme.colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(log.productName,
                                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                                        if (log.sugarType != null && log.sugarType.trim().isNotEmpty)
                                                          Text('  (${log.sugarType})',
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors.grey[600],
                                                                  fontStyle: FontStyle.italic)),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          '${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')}',
                                                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        if (log.emotion != null)
                                                          Text(
                                                            '${log.emotion.emoji} ${log.emotion.label}',
                                                            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                                          ),
                                                        if (log.wasCraving)
                                                          Row(
                                                            children: [
                                                              const SizedBox(width: 10),
                                                              Icon(Icons.bolt, color: Colors.amber, size: 16),
                                                              const Text(" craving",
                                                                  style: TextStyle(fontSize: 12, color: Colors.amber)),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                    if (log.contextNote != null && log.contextNote.trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(
                                                          log.contextNote,
                                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                "${log.sugarGrams}g",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    elevation: 2,
                    child: InkWell(
                      onTap: _updateDailyGoalDialog,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.flag, color: theme.colorScheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Daily Goal Tracker", style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Goal: $dailyGoal g sugar/day",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const Text(
                                    "Tap to set your goal.",
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
