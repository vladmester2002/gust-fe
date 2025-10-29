import 'dart:convert';
import 'dart:math';
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
import 'theme/app_theme.dart';
import 'widgets/gust_card.dart';

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
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.softLavender,
        elevation: 0,
        title: Text(
          'GUST Dashboard',
          style: TextStyle(
            color: AppTheme.primaryPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryPurple),
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
              padding: EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                children: [
                  // Welcome Section with Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.shadowLevel2,
                    ),
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.shadowLevel1,
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                            child: Icon(Icons.person, color: AppTheme.primaryPurple, size: 28),
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _fullName ?? 'GUST User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Streak Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                            vertical: AppTheme.spaceSM,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            boxShadow: AppTheme.shadowLevel1,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_fire_department, color: AppTheme.warningOrange, size: 24),
                              SizedBox(width: AppTheme.spaceSM),
                              Text(
                                '$_streak',
                                style: TextStyle(
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: GustCard(
                          padding: EdgeInsets.all(AppTheme.spaceMD),
                          elevation: 3,
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(AppTheme.spaceSM),
                                decoration: BoxDecoration(
                                  color: AppTheme.successGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check_circle, color: AppTheme.successGreen, size: 24),
                              ),
                              SizedBox(height: AppTheme.spaceSM),
                              Text(
                                '${todayLogs.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Logs Today',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: GustCard(
                          padding: EdgeInsets.all(AppTheme.spaceMD),
                          elevation: 3,
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(AppTheme.spaceSM),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.trending_up, color: AppTheme.infoBlue, size: 24),
                              ),
                              SizedBox(height: AppTheme.spaceSM),
                              Text(
                                '${dailyGoal}g',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Daily Goal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Today's Sugar Intake Card
                  GustCard(
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    elevation: 4,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceMD),
                              decoration: BoxDecoration(
                                color: todaySugar > dailyGoal 
                                    ? AppTheme.errorRed.withOpacity(0.1)
                                    : AppTheme.successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              child: Icon(
                                Icons.local_drink,
                                color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                size: 32,
                              ),
                            ),
                            SizedBox(width: AppTheme.spaceMD),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Sugar Intake",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                  ),
                                  SizedBox(height: AppTheme.spaceXS),
                                  Text(
                                    "$todaySugar g / $dailyGoal g",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceMD),
                              decoration: BoxDecoration(
                                color: todaySugar > dailyGoal 
                                    ? AppTheme.errorRed.withOpacity(0.1)
                                    : AppTheme.successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: todaySugar > dailyGoal 
                                      ? AppTheme.errorRed.withOpacity(0.3)
                                      : AppTheme.successGreen.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    todaySugar > dailyGoal ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                    color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    todaySugar > dailyGoal ? "OVER" : "GOOD",
                                    style: TextStyle(
                                      color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spaceMD),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          child: LinearProgressIndicator(
                            value: (todaySugar / dailyGoal).clamp(0.0, 1.0),
                            backgroundColor: AppTheme.dividerGrey,
                            color: todaySugar > dailyGoal
                                ? AppTheme.errorRed
                                : (todaySugar > dailyGoal * 0.7 ? AppTheme.warningOrange : AppTheme.successGreen),
                            minHeight: 10,
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceMD),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  todaySugar > dailyGoal ? Icons.error_outline : Icons.favorite_border,
                                  size: 18,
                                  color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                ),
                                SizedBox(width: AppTheme.spaceXS),
                                Text(
                                  todaySugar > dailyGoal 
                                      ? "Exceeded by ${todaySugar - dailyGoal} g" 
                                      : "Remaining: $remaining g",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: todaySugar > dailyGoal 
                                    ? AppTheme.errorRed.withOpacity(0.1)
                                    : AppTheme.infoBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                "${((todaySugar / dailyGoal) * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.infoBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Weekly Trends Card
                  GustCard(
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceSM),
                              decoration: BoxDecoration(
                                color: AppTheme.infoBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Icon(Icons.show_chart, color: AppTheme.infoBlue, size: 24),
                            ),
                            SizedBox(width: AppTheme.spaceMD),
                            Text(
                              "Sugar Trends (7 Days)",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spaceMD),
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
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: AppTheme.dividerGrey.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
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
                                        child: Text(
                                          DateFormat('E').format(date),
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    getTitlesWidget: (value, meta) {
                                      if (value % 10 == 0) {
                                        return Text(
                                          '${value.toInt()}g',
                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                        );
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
                                border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                              ),
                              clipData: FlClipData.all(),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < dataPoints.length; i++)
                                      FlSpot(i.toDouble(), dataPoints[i].value.toDouble())
                                  ],
                                  isCurved: true,
                                  barWidth: 3,
                                  color: AppTheme.primaryPurple,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppTheme.primaryPurple.withOpacity(0.2),
                                        AppTheme.primaryPurple.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 5,
                                      color: AppTheme.primaryPurple,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                enabled: true,
                                handleBuiltInTouches: true,
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipBgColor: Colors.white,
                                  tooltipRoundedRadius: AppTheme.radiusSmall,
                                  tooltipPadding: EdgeInsets.all(AppTheme.spaceSM),
                                  tooltipBorder: BorderSide(color: AppTheme.primaryPurple.withOpacity(0.3), width: 1.5),
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((touchedSpot) {
                                      final idx = touchedSpot.spotIndex;
                                      final dayName = DateFormat('EEEE').format(dataPoints[idx].key);
                                      final value = dataPoints[idx].value;
                                      return LineTooltipItem(
                                        "$dayName\n",
                                        TextStyle(
                                          color: AppTheme.primaryPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          height: 1.3,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "$value g",
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Today's Foods Card
                  GustCard(
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceSM),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCoral.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Icon(Icons.fastfood, color: AppTheme.accentCoral, size: 24),
                            ),
                            SizedBox(width: AppTheme.spaceMD),
                            Text(
                              "Today's Foods",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spaceMD),
                        todayLogs.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                                child: Text(
                                  "No entries yet. Start tracking your sugar today!",
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                ),
                              )
                              : Column(
                                  children: [
                                    for (var log in todayLogs)
                                      GestureDetector(
                                        onTap: () => _showRegisterModal(editLog: log),
                                        child: Container(
                                          margin: EdgeInsets.only(bottom: AppTheme.spaceSM),
                                          padding: EdgeInsets.all(AppTheme.spaceMD),
                                          decoration: BoxDecoration(
                                            color: AppTheme.backgroundGrey,
                                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                            border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryPurple.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.circle, size: 8, color: AppTheme.primaryPurple),
                                              ),
                                              SizedBox(width: AppTheme.spaceSM),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          log.productName,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            color: AppTheme.textPrimary,
                                                          ),
                                                        ),
                                                        if (log.sugarType != null && log.sugarType.trim().isNotEmpty)
                                                          Text(
                                                            '  (${log.sugarType})',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: AppTheme.textSecondary,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')}',
                                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        if (log.emotion != null)
                                                          Text(
                                                            '${log.emotion.emoji} ${log.emotion.label}',
                                                            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                                          ),
                                                        if (log.wasCraving)
                                                          Row(
                                                            children: [
                                                              const SizedBox(width: 12),
                                                              Icon(Icons.bolt, color: AppTheme.warningOrange, size: 16),
                                                              Text(
                                                                " craving",
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: AppTheme.warningOrange,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                    if (log.contextNote != null && log.contextNote.trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          log.contextNote,
                                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: AppTheme.spaceSM),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spaceSM,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryPurple.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                ),
                                                child: Text(
                                                  "${log.sugarGrams}g",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: AppTheme.primaryPurple,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Daily Goal Tracker Card
                  GustCard(
                    padding: EdgeInsets.zero,
                    elevation: 4,
                    child: InkWell(
                      onTap: _updateDailyGoalDialog,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spaceLG),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spaceMD),
                              decoration: BoxDecoration(
                                gradient: AppTheme.successGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Icon(Icons.flag, color: Colors.white, size: 28),
                            ),
                            SizedBox(width: AppTheme.spaceMD),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Daily Goal Tracker",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Goal: $dailyGoal g sugar/day",
                                    style: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Tap to set your goal.",
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit, color: AppTheme.primaryPurple, size: 20),
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
