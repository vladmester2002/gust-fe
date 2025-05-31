import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Analytics data DTO
class AnalyticsResponse {
  final String? label;
  final double value;
  final String? emoji;
  final String? detail;

  AnalyticsResponse({
    this.label,
    required this.value,
    this.emoji,
    this.detail,
  });

  factory AnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return AnalyticsResponse(
      label: json['label'] ?? json['date']?.toString(),
      value: (json['value'] is int) ? (json['value'] as int).toDouble() : (json['value'] ?? 0.0).toDouble(),
      emoji: json['emoji'],
      detail: json['detail'],
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  final dynamic logs; // Add this field to match the constructor parameter

  const AnalyticsPage({super.key, required this.logs});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  String? _error;
  List<AnalyticsResponse> _data = [];

  // For month/year selectors
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _fetchTabData();
    });
    _fetchTabData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchTabData() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
    });
    final token = await _getToken();
    if (token == null) return;

    String endpoint = '';
    Map<String, String> params = {};
    switch (_tabController.index) {
      case 0: // Daily Trend
        endpoint = '/api/analytics/daily-trend';
        params = {
          'month': selectedMonth.toString(),
          'year': selectedYear.toString(),
        };
        break;
      case 1: // Emotions
        endpoint = '/api/analytics/emotion-summary';
        params = {
          'month': selectedMonth.toString(),
          'year': selectedYear.toString(),
        };
        break;
      case 2: // Time of Day
        endpoint = '/api/analytics/time-of-day-pattern';
        break;
      case 3: // Monthly Total
        endpoint = '/api/analytics/monthly-total';
        break;
    }
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: params.isNotEmpty ? params : null);
      final resp = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (resp.statusCode == 200) {
        final List raw = jsonDecode(resp.body);
        setState(() {
          _data = raw.map((e) => AnalyticsResponse.fromJson(e)).toList();
        });
      } else {
        setState(() => _error = resp.body);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load data');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildTabContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_data.isEmpty) {
      return const Center(child: Text('No data for this period.'));
    }

    switch (_tabController.index) {
      case 0: // Daily Trend
        return _buildLineChart(_data, "Date", "Sugar (g)");
      case 1: // Emotions
        return _buildEmotionSummary(_data);
      case 2: // Time of Day
        return _buildBarChart(_data, "Time", "Avg Sugar (g)");
      case 3: // Monthly Total
        return _buildBarChart(_data, "Month", "Total Sugar (g)");
      default:
        return const SizedBox();
    }
  }

  Widget _buildLineChart(List<AnalyticsResponse> data, String xLabel, String yLabel) {
    if (data.isEmpty) return const Text('No data.');
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value));
    }
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: data.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev) + 10,
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      int idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      final date = data[idx].label;
                      return Text(date ?? '', style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) => Text('${value.toInt()}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
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
    );
  }

  Widget _buildBarChart(List<AnalyticsResponse> data, String xLabel, String yLabel) {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: [
            for (int i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].value,
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return Text(data[idx].label ?? '', style: const TextStyle(fontSize: 11));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, _) => Text('${value.toInt()}', style: const TextStyle(fontSize: 11)),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, horizontalInterval: 10),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildEmotionSummary(List<AnalyticsResponse> data) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: data.length,
      itemBuilder: (context, idx) {
        final e = data[idx];
        return ListTile(
          leading: Text(e.emoji ?? '🙂', style: const TextStyle(fontSize: 22)),
          title: Text(e.label ?? ''),
          trailing: Text('${e.value.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: selectedMonth,
          items: List.generate(12, (i) {
            return DropdownMenuItem(
              value: i + 1,
              child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1))),
            );
          }),
          onChanged: (val) {
            setState(() => selectedMonth = val!);
            _fetchTabData();
          },
        ),
        const SizedBox(width: 16),
        DropdownButton<int>(
          value: selectedYear,
          items: List.generate(5, (i) {
            final year = DateTime.now().year - i;
            return DropdownMenuItem(value: year, child: Text('$year'));
          }),
          onChanged: (val) {
            setState(() => selectedYear = val!);
            _fetchTabData();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('Analytics'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.outline,
            tabs: const [
              Tab(text: "Daily Trend"),
              Tab(text: "Emotions"),
              Tab(text: "Time of Day"),
              Tab(text: "Monthly"),
            ],
          ),
          if (_tabController.index == 0 || _tabController.index == 1)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: _buildMonthSelector(),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }
}
