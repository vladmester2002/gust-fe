import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:gust_fe/SugarLog.dart';
import 'package:intl/intl.dart';
import 'emotion.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.logs});
  final List<SugarLog> logs; // No longer needed for state, but kept for backward compatibility

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;
  List<SugarLog> _logs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final token = await _getToken();
    if (token == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Please login again.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load logs: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading logs: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createLog(Map<String, dynamic> logData) async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Please login again.')),
      );
      return;
    }
    final url = Uri.parse('$baseUrl/api/sugarlogs');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(logData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final log = SugarLog.fromJson(jsonDecode(response.body));
      setState(() => _logs.add(log));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sugar log added!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add log: ${response.body}')),
      );
    }
  }

  Future<void> _updateLog(int id, Map<String, dynamic> logData) async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Please login again.')),
      );
      return;
    }
    final url = Uri.parse('$baseUrl/api/sugarlogs/$id');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(logData),
    );
    if (response.statusCode == 200) {
      final updated = SugarLog.fromJson(jsonDecode(response.body));
      setState(() {
        _logs = _logs.map((log) => log.id == id ? updated : log).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sugar log updated!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update log: ${response.body}')),
      );
    }
  }

  Future<void> _deleteLog(int id) async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Please login again.')),
      );
      return;
    }
    final url = Uri.parse('$baseUrl/api/sugarlogs/$id');
    final response = await http.delete(url, headers: {
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode == 204) {
      setState(() {
        _logs.removeWhere((log) => log.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sugar log deleted!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete log: ${response.body}')),
      );
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      _showRegisterModal();
    } else if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile coming soon")),
      );
    } else if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings coming soon")),
      );
    }
  }

  Future<void> _showRegisterModal({SugarLog? editLog}) async {
    final theme = Theme.of(context);

    final _formKey = GlobalKey<FormState>();
    final sugarController = TextEditingController(text: editLog?.sugarGrams.toString() ?? '');
    final productNameController = TextEditingController(text: editLog?.productName ?? '');
    final sugarTypeController = TextEditingController(text: editLog?.sugarType ?? '');
    final contextNoteController = TextEditingController(text: editLog?.contextNote ?? '');
    final locationController = TextEditingController(text: editLog?.location ?? '');

    DateTime selectedDate = editLog?.date ?? DateTime.now();
    TimeOfDay selectedTime = editLog != null
        ? TimeOfDay(hour: editLog.hour, minute: editLog.minute)
        : TimeOfDay.now();
    Emotion selectedEmotion = editLog?.emotion ?? Emotion.NEUTRAL;
    bool wasCraving = editLog?.wasCraving ?? false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(editLog == null ? "Log Sugar Intake" : "Edit Sugar Log"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 350,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: sugarController,
                          decoration: InputDecoration(labelText: "Sugar (g)"),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? "Required" : null,
                        ),
                        TextFormField(
                          controller: productNameController,
                          decoration: InputDecoration(labelText: "Product/Food Name"),
                        ),
                        TextFormField(
                          controller: sugarTypeController,
                          decoration: InputDecoration(labelText: "Sugar Type"),
                        ),
                        TextFormField(
                          controller: contextNoteController,
                          decoration: InputDecoration(labelText: "Context Note"),
                        ),
                        TextFormField(
                          controller: locationController,
                          decoration: InputDecoration(labelText: "Location"),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text("Date: ${DateFormat.yMd().format(selectedDate)}"),
                            ),
                            IconButton(
                              icon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text("Time: ${selectedTime.format(context)}"),
                            ),
                            IconButton(
                              icon: Icon(Icons.access_time, color: theme.colorScheme.primary),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setState(() => selectedTime = picked);
                                }
                              },
                            ),
                          ],
                        ),
                        DropdownButtonFormField<Emotion>(
                          value: selectedEmotion,
                          onChanged: (e) => setState(() => selectedEmotion = e!),
                          items: Emotion.values.map((e) => DropdownMenuItem(
                            value: e,
                            child: Text("${e.emoji} ${e.label}"),
                          )).toList(),
                          decoration: InputDecoration(labelText: "Emotion"),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Was craving?"),
                            Switch(
                              value: wasCraving,
                              onChanged: (v) => setState(() => wasCraving = v),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            if (editLog != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteLog(editLog.id);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _loading = true);

                final logData = {
                  "sugarGrams": int.tryParse(sugarController.text) ?? 0,
                  "date": DateFormat('yyyy-MM-dd').format(selectedDate),
                  "hour": selectedTime.hour,
                  "minute": selectedTime.minute,
                  "productName": productNameController.text,
                  "sugarType": sugarTypeController.text,
                  "contextNote": contextNoteController.text,
                  "emotion": selectedEmotion.name,
                  "location": locationController.text,
                  "wasCraving": wasCraving
                };

                if (editLog == null) {
                  Navigator.pop(context);
                  await _createLog(logData);
                } else {
                  Navigator.pop(context);
                  await _updateLog(editLog.id, logData);
                }
                setState(() => _loading = false);
              },
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(editLog == null ? "Log" : "Update"),
            ),
          ],
        );
      },
    );
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

    final dailyGoal = 75;
    final remaining = (dailyGoal - todaySugar).clamp(0, dailyGoal);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('GUST Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: theme.textTheme.bodySmall),
                    Text('GUST User', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                )
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
                          maxY: (dataPoints.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 10).toDouble(),
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
                                reservedSize: 32,
                                getTitlesWidget: (value, _) =>
                                    Text('${value.toInt()}g', style: const TextStyle(fontSize: 11)),
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
                                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(log.productName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                        Text("${log.sugarGrams}g", style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.outline,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Register'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
