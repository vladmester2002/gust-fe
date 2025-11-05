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

  /// Returns a time-appropriate greeting message
  String _getDailyGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning! Let's make today sugar-free ☀️";
    } else if (hour < 17) {
      return "Good afternoon! Stay strong 💪";
    } else {
      return "Good evening! You've got this 🌙";
    }
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
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: AppTheme.primaryPurple.withOpacity(0.1),
        title: Row(
          children: [
            // Gradient GUST icon
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6A1B9A),
                    Color(0xFF8E24AA),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            // Title with gradient text effect
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Color(0xFF6A1B9A),
                  Color(0xFF8E24AA),
                ],
              ).createShader(bounds),
              child: Text(
                'GUST Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Stylish refresh button
          Container(
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryPurple.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryPurple),
              iconSize: 22,
              onPressed: () {
                _fetchLogs();
                _loadUserStreak();
                _loadUserProfile();
              },
              tooltip: "Refresh",
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                children: [
                  // Stunning Welcome Section with Enhanced Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6A1B9A), // Deep purple
                          Color(0xFF8E24AA), // Medium purple  
                          Color(0xFFAB47BC), // Light purple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${_fullName ?? 'User'} 👋',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getDailyGreeting(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Elevated Streak Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: AppTheme.warningOrange,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_streak',
                                    style: TextStyle(
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'days',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  
                  // Today's Sugar Intake Card - Fixed Overflow
                  GustCard(
                    padding: EdgeInsets.all(AppTheme.spaceLG),
                    elevation: 4,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon with improved sizing
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: todaySugar > dailyGoal 
                                    ? AppTheme.errorRed.withOpacity(0.1)
                                    : AppTheme.successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              child: Icon(
                                Icons.local_drink,
                                color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: AppTheme.spaceMD),
                            // Expanded content section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Sugar Intake",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
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
                            // Status badge with fixed sizing
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    todaySugar > dailyGoal ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                    color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    todaySugar > dailyGoal ? "OVER" : "GOOD",
                                    style: TextStyle(
                                      color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spaceMD),
                        // Progress bar with gradient
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          child: Stack(
                            children: [
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppTheme.dividerGrey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (todaySugar / dailyGoal).clamp(0.0, 1.0),
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: todaySugar > dailyGoal
                                          ? [AppTheme.errorRed, AppTheme.errorRed.withOpacity(0.8)]
                                          : (todaySugar > dailyGoal * 0.7 
                                              ? [AppTheme.warningOrange, AppTheme.warningOrange.withOpacity(0.8)]
                                              : [AppTheme.successGreen, AppTheme.accentTeal]),
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppTheme.spaceMD),
                        // Bottom info row with flexible layout
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              flex: 3,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    todaySugar > dailyGoal ? Icons.error_outline : Icons.favorite_border,
                                    size: 16,
                                    color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.successGreen,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      todaySugar > dailyGoal 
                                          ? "Exceeded by ${todaySugar - dailyGoal}g" 
                                          : "Remaining: ${remaining}g",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: todaySugar > dailyGoal 
                                      ? [AppTheme.errorRed.withOpacity(0.15), AppTheme.errorRed.withOpacity(0.1)]
                                      : [AppTheme.infoBlue.withOpacity(0.15), AppTheme.infoBlue.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                border: Border.all(
                                  color: todaySugar > dailyGoal 
                                      ? AppTheme.errorRed.withOpacity(0.3)
                                      : AppTheme.infoBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                "${((todaySugar / dailyGoal) * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: todaySugar > dailyGoal ? AppTheme.errorRed : AppTheme.infoBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceLG),
                  
                  // Weekly Trends Card - Bar Chart Design
                  GustCard(
                    padding: EdgeInsets.all(20),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.primaryPurple.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Weekly Overview",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    "Last 7 days",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Average badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.infoBlue.withOpacity(0.15),
                                    AppTheme.infoBlue.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.infoBlue.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.show_chart, 
                                    color: AppTheme.infoBlue, 
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "${(dataPoints.fold(0, (sum, point) => sum + point.value) / dataPoints.length).toStringAsFixed(0)}g avg",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppTheme.infoBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        // Bar Chart
                        Container(
                          height: 240,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: ((maxY / 10).ceil() * 10).toDouble(),
                              minY: 0,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipBgColor: AppTheme.primaryPurple,
                                  tooltipRoundedRadius: 12,
                                  tooltipPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final date = dataPoints[group.x.toInt()].key;
                                    final value = dataPoints[group.x.toInt()].value;
                                    return BarTooltipItem(
                                      '${DateFormat('EEE, MMM d').format(date)}\n',
                                      TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${value}g sugar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      int idx = value.toInt();
                                      if (idx < 0 || idx >= dataPoints.length) return const SizedBox();
                                      final date = dataPoints[idx].key;
                                      final isToday = date.day == DateTime.now().day && 
                                                      date.month == DateTime.now().month;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              DateFormat('EEE').format(date),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isToday ? AppTheme.primaryPurple : AppTheme.textSecondary,
                                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              DateFormat('d').format(date),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isToday ? AppTheme.primaryPurple : AppTheme.textSecondary.withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 20,
                                    getTitlesWidget: (value, meta) {
                                      if (value == meta.max || value == meta.min) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text(
                                          '${value.toInt()}g',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 20,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: AppTheme.dividerGrey.withOpacity(0.2),
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                  );
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(dataPoints.length, (index) {
                                final date = dataPoints[index].key;
                                final value = dataPoints[index].value;
                                final isToday = date.day == DateTime.now().day && 
                                                date.month == DateTime.now().month;
                                final isOverGoal = value > dailyGoal;
                                
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: value.toDouble(),
                                      width: 28,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(8),
                                        bottom: Radius.circular(4),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: isToday
                                            ? [AppTheme.warningOrange, AppTheme.warningOrange.withOpacity(0.7)]
                                            : isOverGoal
                                                ? [AppTheme.errorRed.withOpacity(0.8), AppTheme.errorRed]
                                                : [AppTheme.successGreen.withOpacity(0.8), AppTheme.accentTeal],
                                      ),
                                      rodStackItems: [],
                                      backDrawRodData: BackgroundBarChartRodData(
                                        show: true,
                                        toY: ((maxY / 10).ceil() * 10).toDouble(),
                                        color: AppTheme.dividerGrey.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                  showingTooltipIndicators: isToday ? [0] : [],
                                );
                              }),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(AppTheme.successGreen, 'Under Goal'),
                            SizedBox(width: 16),
                            _buildLegendItem(AppTheme.warningOrange, 'Today'),
                            SizedBox(width: 16),
                            _buildLegendItem(AppTheme.errorRed, 'Over Goal'),
                          ],
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
                                          margin: EdgeInsets.only(bottom: AppTheme.spaceMD),
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryPurple.withOpacity(0.08),
                                                blurRadius: 12,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: AppTheme.dividerGrey.withOpacity(0.15),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Left accent indicator
                                              Container(
                                                width: 4,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      AppTheme.primaryPurple,
                                                      AppTheme.primaryPurple.withOpacity(0.5),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              // Main content
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Product name
                                                    Text(
                                                      log.productName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 16,
                                                        color: AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    // Time, emotion, craving - Using Wrap to prevent overflow
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 6,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        // Time chip
                                                        Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.infoBlue.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.access_time, size: 12, color: AppTheme.infoBlue),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '${log.hour.toString().padLeft(2, '0')}:${log.minute.toString().padLeft(2, '0')}',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: AppTheme.infoBlue,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Emotion chip
                                                        if (log.emotion != null)
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.successGreen.withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              '${log.emotion.emoji} ${log.emotion.label}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppTheme.successGreen.withOpacity(0.8),
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        // Craving chip - Fixed overflow issue
                                                        if (log.wasCraving)
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.warningOrange.withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(Icons.bolt, color: AppTheme.warningOrange, size: 12),
                                                                SizedBox(width: 4),
                                                                Text(
                                                                  "Craving",
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: AppTheme.warningOrange,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        // Sugar type chip
                                                        if (log.sugarType != null && log.sugarType.trim().isNotEmpty)
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.primaryPurple.withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              log.sugarType,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppTheme.primaryPurple,
                                                                fontWeight: FontWeight.w600,
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    // Context note
                                                    if (log.contextNote != null && log.contextNote.trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8),
                                                        child: Text(
                                                          log.contextNote,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: AppTheme.textSecondary,
                                                            height: 1.4,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              // Sugar amount badge - inline design
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppTheme.primaryPurple,
                                                      AppTheme.primaryPurple.withOpacity(0.8),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppTheme.primaryPurple.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  "${log.sugarGrams}g",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
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

  // Helper method for chart legend
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
