import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'emotion.dart';
import 'package:another_flushbar/flushbar.dart';

// Add for file download:
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart'; // DOnly for mobile/desktop
import 'package:open_file/open_file.dart'; // Only for mobile/desktop
import 'package:flutter/services.dart' show rootBundle;

import 'web_csv_download_stub.dart'
    if (dart.library.html) 'web_csv_download.dart';

const List<String> monthOrder = [
  "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
  "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
];

/// You can customize these time slots and their emoji here:
const List<String> timeSlots = ["Morning", "Afternoon", "Evening", "Night"];
const Map<String, String> timeSlotEmojis = {
  "Morning": "🌅",
  "Afternoon": "🌞",
  "Evening": "🌇",
  "Night": "🌙",
};

String getEmotionEmoji(String? label) {
  // For time of day slots, return special emoji:
  if (label != null && timeSlotEmojis.containsKey(label)) {
    return timeSlotEmojis[label]!;
  }
  if (label == null) return Emotion.NEUTRAL.emoji;
  final labelUpper = label.trim().toUpperCase();
  for (final emotion in Emotion.values) {
    if (emotion.label.toUpperCase() == labelUpper || emotion.name == labelUpper) {
      return emotion.emoji;
    }
  }
  return Emotion.NEUTRAL.emoji;
}

double getCleanMaxY(double maxValue) {
  if (maxValue <= 10) return 10;
  int exp = maxValue.toInt().toString().length - 1;
  int base = pow(10, exp).toInt();
  double rounded = (((maxValue + base - 1) ~/ base) * base).toDouble();
  if (rounded - maxValue < base / 2) return rounded.toDouble();
  if (base > 10) {
    final rounded2 = ((maxValue + base ~/ 2 - 1) ~/ (base ~/ 2)) * (base ~/ 2);
    if ((rounded2 - maxValue).abs() < (rounded - maxValue).abs()) return rounded2.toDouble();
  }
  return rounded.toDouble();
}

int getYAxisStep(double maxY) {
  if (maxY <= 10) return 2;
  if (maxY <= 50) return 10;
  if (maxY <= 100) return 20;
  if (maxY <= 200) return 40;
  return (maxY ~/ 5).clamp(1, maxY.toInt());
}

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
  final dynamic logs;
  const AnalyticsPage({super.key, required this.logs});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  String? _error;
  List<AnalyticsResponse> _data = [];
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int _lastTabIndex = 0;
  bool _showContent = true;
  bool _modalOpen = false;
  final DateTime _currentDay = DateTime.now();

  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchTabData();
  }

  void _onTabChanged() {
    if (_tabController.index != _lastTabIndex && (_tabController.index == 0 || _tabController.index == 1)) {
      setState(() {
        selectedMonth = DateTime.now().month;
        selectedYear = DateTime.now().year;
      });
    }
    _lastTabIndex = _tabController.index;
    _fetchTabData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ------ CSV EXPORT BUTTON FUNCTIONALITY ---------
  Future<void> _exportCsv() async {
  setState(() {
    _downloading = true;
  });
  try {
    final token = await _getToken();
    if (token == null) throw Exception("Not logged in");

    // Add month and year params
    final uri = Uri.parse('$baseUrl/api/analytics/export/csv')
      .replace(queryParameters: {
        'month': selectedMonth.toString(),
        'year': selectedYear.toString(),
      });

    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (resp.statusCode != 200) {
      throw Exception("Failed to download file: ${resp.body}");
    }

    final fileName = 'sugar_log_export_${selectedYear}_${selectedMonth.toString().padLeft(2, '0')}.csv';

    if (kIsWeb) {
      downloadCsvWeb(resp.bodyBytes, fileName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);
      await OpenFile.open(file.path);
    }

    // --- Use Flushbar instead of SnackBar here:
    Flushbar(
      message: 'CSV file exported successfully!',
      icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: Colors.green[700]!,
    ).show(context);

  } catch (e) {
    Flushbar(
      message: 'Failed to export CSV: $e',
      icon: const Icon(Icons.error, color: Colors.redAccent, size: 28),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: Colors.red[700]!,
    ).show(context);
  } finally {
    setState(() {
      _downloading = false;
    });
  }
}

  List<AnalyticsResponse> _sortMonthlyData(List<AnalyticsResponse> data) {
    List<AnalyticsResponse> sortedData = List.from(data);
    sortedData.sort((a, b) {
      String la = (a.label ?? "").toUpperCase();
      String lb = (b.label ?? "").toUpperCase();
      int ia = monthOrder.indexOf(la);
      int ib = monthOrder.indexOf(lb);
      if (ia == -1 || ib == -1) {
        return la.compareTo(lb);
      }
      return ia.compareTo(ib);
    });
    return sortedData;
  }

  List<AnalyticsResponse> _sortDataByDate(List<AnalyticsResponse> data) {
    List<AnalyticsResponse> sortedData = List.from(data);
    sortedData.sort((a, b) {
      try {
        final da = DateTime.parse(a.label ?? '');
        final db = DateTime.parse(b.label ?? '');
        return da.compareTo(db);
      } catch (_) {
        return (a.label ?? '').compareTo(b.label ?? '');
      }
    });
    return sortedData;
  }

  /// Ensures the bar chart always has [Morning, Afternoon, Evening, Night] in order, using 0 if missing.
  List<AnalyticsResponse> _fillTimeSlots(List<AnalyticsResponse> data) {
    Map<String, AnalyticsResponse> slotMap = {
      for (var e in data)
        if (e.label != null) e.label!: e,
    };
    return [
      for (final slot in timeSlots)
        slotMap[slot] ??
            AnalyticsResponse(
                label: slot,
                value: 0,
                emoji: timeSlotEmojis[slot],
                detail: ''),
    ];
  }

  Future<void> _fetchTabData() async {
    setState(() {
      _showContent = false;
    });
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
    });
    final token = await _getToken();
    if (token == null) return;

    String endpoint = '';
    Map<String, String> params = {};
    if (_tabController.index == 2) {
      endpoint = '/api/analytics/time-of-day-pattern';
      params = {
        'date': DateFormat('yyyy-MM-dd').format(_currentDay),
      };
    } else {
      switch (_tabController.index) {
        case 0:
          endpoint = '/api/analytics/daily-trend';
          params = {
            'month': selectedMonth.toString(),
            'year': selectedYear.toString(),
          };
          break;
        case 1:
          endpoint = '/api/analytics/emotion-summary';
          params = {
            'month': selectedMonth.toString(),
            'year': selectedYear.toString(),
          };
          break;
        case 3:
          endpoint = '/api/analytics/monthly-total';
          break;
      }
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
      setState(() {
        _loading = false;
        _showContent = true;
      });
    }
  }

  Widget _buildAnimatedTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _showContent
          ? _buildTabContent()
          : const SizedBox(key: ValueKey('empty')),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  Widget _buildTabContent() {
  if (_loading) return const Center(child: CircularProgressIndicator());
  if (_error != null) return _buildErrorState(_error!);
  if (_data.isEmpty) return _buildEmptyState();

  // --- Time of Day tab - always today only, no selectors
  if (_tabController.index == 2) {
    final slotData = _fillTimeSlots(_data);
    return _buildAnalyticsCard(
      title: "Time of Day Patterns",
      description: "Sugar intake for each time slot today (${DateFormat('yMMMEd').format(_currentDay)}).",
      stats: _getTimeOfDayStats(slotData),
      onRefresh: _fetchTabData,
      chart: _buildBarChart(slotData, "Time"),
      showExportButton: false, // <--- Hide download button here
    );
  }

  switch (_tabController.index) {
    case 0:
      return _buildAnalyticsCard(
        title: "Daily Sugar Intake Trend",
        description:
            "Track how your sugar consumption fluctuates day-by-day in the selected month.",
        stats: _getTrendStats(_data),
        onRefresh: _fetchTabData,
        chart: _buildLineChart(_data),
        showExportButton: true, // <--- SHOW button here!
      );
    case 1:
      return _buildAnalyticsCard(
        title: "Emotion Summary",
        description:
            "See which emotions appeared most frequently this month, and how they relate to your sugar intake.",
        stats: _getEmotionStats(_data),
        onRefresh: _fetchTabData,
        chart: _buildEmotionSummary(_data),
        showExportButton: false, // <--- Hide
      );
    case 3:
      return _buildAnalyticsCard(
        title: "Monthly Total",
        description:
            "View your total sugar intake per month and look for long-term trends.",
        stats: _getMonthlyStats(_data),
        onRefresh: _fetchTabData,
        chart: _buildBarChart(_data, "Month"),
        showExportButton: false, // <--- Hide
      );
    default:
      return const SizedBox();
  }
}

  Widget _buildAnalyticsCard({
    required String title,
    required String description,
    required Widget chart,
    required List<Widget> stats,
    required VoidCallback onRefresh,
    bool showExportButton = false, // <--- add this param!
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.purple[50],
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.deepPurple[800],
                          fontWeight: FontWeight.w700)),
                ),
                if (showExportButton) // <-- only show when needed!
                  Tooltip(
                    message: "Export This Month as CSV",
                    child: IconButton(
                      icon: _downloading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.deepPurple,
                              ))
                          : const Icon(Icons.download_rounded),
                      color: Colors.deepPurple,
                      splashRadius: 24,
                      onPressed: _downloading ? null : _exportCsv,
                    ),
                  ),
                Tooltip(
                  message: "Refresh",
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    color: Colors.deepPurple,
                    splashRadius: 24,
                    onPressed: onRefresh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(description,
                  style: TextStyle(
                      color: Colors.purple[700],
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ),
            if (stats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: stats,
                ),
              ),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<AnalyticsResponse> data) {
    final sortedData = _sortDataByDate(data);
    final spots = <FlSpot>[];
    for (var i = 0; i < sortedData.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedData[i].value));
    }
    double rawMaxY =
        sortedData.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev);
    double maxY = getCleanMaxY(rawMaxY);
    int yStep = getYAxisStep(maxY);

    return GestureDetector(
      child: SizedBox(
        height: 260, // FIX: increased from 240 to 260 for line chart labels too
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yStep.toDouble(),
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.purple.withOpacity(0.09),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40, // FIX: was 38, slightly increased
                  interval: (sortedData.length <= 7)
                      ? 1
                      : (sortedData.length / 6).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    int idx = value.toInt();
                    if (idx < 0 || idx >= sortedData.length) return const SizedBox();
                    if (sortedData.length > 8 && idx % ((sortedData.length / 6).ceil()) != 0) {
                      return const SizedBox();
                    }
                    final dateStr = sortedData[idx].label;
                    String shortLabel;
                    if (dateStr != null &&
                        dateStr.length > 7 &&
                        dateStr.contains('-')) {
                      try {
                        final dt = DateTime.parse(dateStr);
                        shortLabel = DateFormat('MMM d').format(dt);
                      } catch (_) {
                        shortLabel = dateStr;
                      }
                    } else {
                      shortLabel = dateStr ?? '';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Text(shortLabel,
                            style: TextStyle(fontSize: 11, color: Colors.purple[800])),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == maxY || value % yStep == 0) {
                      return Text('${value.toInt()}',
                          style: TextStyle(fontSize: 12, color: Colors.purple[700]));
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
              border: Border.all(color: Colors.purple.shade100),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 4,
                color: Colors.deepPurple,
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.deepPurple.withOpacity(0.14),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 5,
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: Colors.deepPurple,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.white,
                tooltipRoundedRadius: 10,
                tooltipPadding: const EdgeInsets.all(8),
                tooltipBorder: BorderSide(color: Colors.deepPurple.shade200),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final idx = touchedSpot.spotIndex;
                    final resp = sortedData[idx];
                    return LineTooltipItem(
                      "${resp.label ?? ''}\n",
                      const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: "${resp.value.toStringAsFixed(1)} g",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
              touchCallback: (event, res) {
                if (event is FlTapUpEvent && res != null &&
                    res.lineBarSpots != null &&
                    res.lineBarSpots!.isNotEmpty) {
                  final idx = res.lineBarSpots!.first.spotIndex;
                  final resp = sortedData[idx];
                  _showDetailSheet(resp, sortedData);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<AnalyticsResponse> data, String xLabel) {
    List<AnalyticsResponse> sortedData;
    if (xLabel == "Time") {
      // Always fill all time slots, in the right order
      sortedData = _fillTimeSlots(data);
    } else if (xLabel == "Month") {
      sortedData = _sortMonthlyData(data);
    } else if (xLabel == "Date") {
      sortedData = _sortDataByDate(data);
    } else {
      sortedData = List.from(data);
    }
    double rawMaxY =
        sortedData.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev);
    double maxY = getCleanMaxY(rawMaxY);
    int yStep = getYAxisStep(maxY);

    return SizedBox(
      height: 320, // FIX: Increased from 240 to 320 to give enough room for bottom labels/emojis
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.white,
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.all(10),
              tooltipBorder: BorderSide(color: Colors.deepPurple.shade200),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final resp = sortedData[group.x.toInt()];
                final label = resp.label ?? '';
                final emoji = getEmotionEmoji(label);
                return BarTooltipItem(
                  "$emoji $label\n",
                  const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  children: [
                    TextSpan(
                      text: "${resp.value.toStringAsFixed(1)} g",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
            touchCallback: (event, res) {
              if (event is FlTapUpEvent &&
                  res != null &&
                  res.spot != null &&
                  res.spot!.touchedBarGroupIndex < sortedData.length) {
                final idx = res.spot!.touchedBarGroupIndex;
                final resp = sortedData[idx];
                _showDetailSheet(resp, sortedData);
              }
            },
          ),
          barGroups: [
            for (int i = 0; i < sortedData.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: sortedData[i].value,
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.deepPurpleAccent,
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: Colors.deepPurpleAccent.withOpacity(0.07),
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 62, // FIX: increased from default (was usually ~32-38) to 62 for emoji/text labels
                interval: 1,
                getTitlesWidget: (value, _) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= sortedData.length) return const SizedBox();
                  final slot = sortedData[idx].label ?? '';
                  final emoji = getEmotionEmoji(slot);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)), // FIX: emoji font up to 24 for clarity
                      Transform.rotate(
                        angle: -0.4,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3.0), // FIX: Add some padding so text doesn't hit emoji
                          child: Text(
                            slot,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.purple[800],
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, _) {
                  if (value == 0 || value == maxY || value % yStep == 0) {
                    return Text('${value.toInt()}',
                        style: TextStyle(fontSize: 12, color: Colors.purple[700]));
                  }
                  return const SizedBox();
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: yStep.toDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.purple.withOpacity(0.10),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.purple.shade100)),
        ),
      ),
    );
  }

  Widget _buildEmotionSummary(List<AnalyticsResponse> data) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (context, i) =>
          Divider(indent: 18, endIndent: 18, color: Colors.purple[100]),
      itemBuilder: (context, idx) {
        final e = data[idx];
        final emoji = getEmotionEmoji(e.label);
        return ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 28)),
          title: Text(
            e.label ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          trailing: Text(
            "${e.value.toStringAsFixed(1)}x",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onTap: () => _showDetailSheet(e, data),
        );
      },
    );
  }

  List<Widget> _getTrendStats(List<AnalyticsResponse> data) {
    if (data.isEmpty) return [];
    final values = data.map((e) => e.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final maxValue = values.reduce(max);
    final minValue = values.reduce(min);
    return [
      _buildStatTile("Avg", "${avg.toStringAsFixed(1)}g"),
      _buildStatTile("Max", "${maxValue.toStringAsFixed(1)}g"),
      _buildStatTile("Min", "${minValue.toStringAsFixed(1)}g"),
    ];
  }

  List<Widget> _getEmotionStats(List<AnalyticsResponse> data) {
    if (data.isEmpty) return [];
    data.sort((a, b) => b.value.compareTo(a.value));
    final most = data.first;
    return [
      _buildStatTile("Most", "${getEmotionEmoji(most.label)} ${most.label}"),
      if (data.length > 1)
        _buildStatTile("Second", "${getEmotionEmoji(data[1].label)} ${data[1].label}"),
    ];
  }

  List<Widget> _getTimeOfDayStats(List<AnalyticsResponse> data) {
    if (data.isEmpty) return [];
    // Always sorted in [Morning, Afternoon, Evening, Night] order
    List<AnalyticsResponse> ordered = _fillTimeSlots(data);
    ordered.sort((a, b) => timeSlots.indexOf(a.label ?? '') - timeSlots.indexOf(b.label ?? ''));
    final peak = ordered.reduce((a, b) => a.value >= b.value ? a : b);
    return [
      _buildStatTile("Peak", peak.label ?? '', emoji: getEmotionEmoji(peak.label)),
      _buildStatTile("Value", "${peak.value.toStringAsFixed(1)}g"),
    ];
  }

  List<Widget> _getMonthlyStats(List<AnalyticsResponse> data) {
    if (data.isEmpty) return [];
    data.sort((a, b) => b.value.compareTo(a.value));
    final highest = data.first;
    return [
      _buildStatTile("Highest", highest.label ?? '', emoji: getEmotionEmoji(highest.label)),
      _buildStatTile("Total", "${highest.value.toStringAsFixed(1)}g"),
    ];
  }

  Widget _buildStatTile(String label, String value, {String? emoji}) {
    return Column(
      children: [
        if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.purple)),
      ],
    );
  }

  Widget _buildEmptyState() {
    final emoji = [
      "📉", "🦄", "📊", "🤷‍♂️", "☁️", "🥲"
    ]..shuffle();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji.first, style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          Text('No data for this period.',
              style: TextStyle(color: Colors.purple[300], fontSize: 16)),
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.deepPurple),
            label: const Text('Try Again'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            onPressed: _fetchTabData,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("❌", style: TextStyle(fontSize: 54)),
          const SizedBox(height: 10),
          Text(error, style: const TextStyle(color: Colors.red, fontSize: 16)),
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.deepPurple),
            label: const Text('Try Again'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            onPressed: _fetchTabData,
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(AnalyticsResponse resp, List<AnalyticsResponse> allData) async {
    if (_modalOpen) return;
    _modalOpen = true;

    double? minVal, maxVal, avgVal, sumVal;
    int rank = -1;
    if (allData.isNotEmpty) {
      minVal = allData.map((e) => e.value).reduce(min);
      maxVal = allData.map((e) => e.value).reduce(max);
      avgVal = allData.map((e) => e.value).reduce((a, b) => a + b) / allData.length;
      sumVal = allData.map((e) => e.value).reduce((a, b) => a + b);
      rank = allData.indexWhere((e) => e.value == resp.value);
    }

    String? prettyDate;
    try {
      if (resp.label != null && resp.label!.contains('-')) {
        final date = DateTime.parse(resp.label!);
        prettyDate = DateFormat('EEEE, d MMMM y').format(date);
      }
    } catch (_) {}

    String percentageOfAvg = "";
    String percentageOfMax = "";
    if (avgVal != null && avgVal > 0) {
      percentageOfAvg = "${((resp.value / avgVal) * 100).toStringAsFixed(0)}% of avg";
    }
    if (maxVal != null && maxVal > 0) {
      percentageOfMax = "${((resp.value / maxVal) * 100).toStringAsFixed(0)}% of max";
    }

    String contextMessage = "";
    if (avgVal != null) {
      if (resp.value >= avgVal * 1.25) {
        contextMessage = "⬆️ Above average";
      } else if (resp.value <= avgVal * 0.75) {
        contextMessage = "⬇️ Below average";
      } else {
        contextMessage = "↔️ Around average";
      }
    }

    String? percentageOfTotal;
    if (sumVal != null && sumVal > 0) {
      percentageOfTotal = "${((resp.value / sumVal) * 100).toStringAsFixed(1)}% of total";
    }

    bool isMax = (maxVal != null && resp.value == maxVal);
    bool isMin = (minVal != null && resp.value == minVal);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(10),
                      ))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(getEmotionEmoji(resp.label), style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      resp.label ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ),
                  if (isMax)
                    Tooltip(
                      message: "This is the highest value!",
                      child: Icon(Icons.arrow_upward, color: Colors.green[700], size: 26),
                    ),
                  if (isMin)
                    Tooltip(
                      message: "This is the lowest value!",
                      child: Icon(Icons.arrow_downward, color: Colors.red[400], size: 26),
                    ),
                ],
              ),
              if (prettyDate != null) ...[
                const SizedBox(height: 6),
                Text(prettyDate, style: const TextStyle(fontSize: 15, color: Colors.deepPurple)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    "Value: ",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple[600]),
                  ),
                  Text(
                    resp.value.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                    ),
                  ),
                  if (percentageOfTotal != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      percentageOfTotal,
                      style: const TextStyle(fontSize: 14, color: Colors.deepPurple),
                    ),
                  ]
                ],
              ),
              if (percentageOfAvg.isNotEmpty || percentageOfMax.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (percentageOfAvg.isNotEmpty)
                      Text(
                        percentageOfAvg,
                        style: TextStyle(color: Colors.purple[700], fontSize: 13),
                      ),
                    if (percentageOfMax.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          percentageOfMax,
                          style: TextStyle(color: Colors.purple[700], fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
              if (contextMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  contextMessage,
                  style: TextStyle(
                      fontSize: 15,
                      color: contextMessage.contains("Above")
                          ? Colors.green[700]
                          : contextMessage.contains("Below")
                              ? Colors.red[400]
                              : Colors.purple[700],
                      fontWeight: FontWeight.w500),
                ),
              ],
              if (resp.detail != null && resp.detail!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  resp.detail!,
                  style: const TextStyle(
                      fontSize: 15, color: Colors.black87, height: 1.4),
                ),
              ],
              if (minVal != null && maxVal != null && avgVal != null) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text("Min", style: TextStyle(fontSize: 13, color: Colors.purple)),
                        Text("${minVal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        Text("Avg", style: TextStyle(fontSize: 13, color: Colors.purple)),
                        Text("${avgVal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        Text("Max", style: TextStyle(fontSize: 13, color: Colors.purple)),
                        Text("${maxVal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
    _modalOpen = false;
  }

  Widget _buildMonthSelector() {
    final Color dropdownTextColor = Colors.deepPurple;
    final Color dropdownBgColor = Colors.purple[50]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: dropdownBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<int>(
              value: selectedMonth,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: dropdownBgColor,
              style: TextStyle(color: dropdownTextColor, fontSize: 16),
              items: List.generate(12, (i) {
                return DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(2000, i + 1)),
                    style: TextStyle(color: dropdownTextColor),
                  ),
                );
              }),
              onChanged: (val) {
                setState(() => selectedMonth = val!);
                _fetchTabData();
              },
              iconEnabledColor: dropdownTextColor,
              iconDisabledColor: dropdownTextColor,
              underline: const SizedBox(),
              isDense: true,
            ),
          ),
          const SizedBox(width: 18),
          Container(
            decoration: BoxDecoration(
              color: dropdownBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<int>(
              value: selectedYear,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: dropdownBgColor,
              style: TextStyle(color: dropdownTextColor, fontSize: 16),
              items: List.generate(5, (i) {
                final year = DateTime.now().year - i;
                return DropdownMenuItem(
                  value: year,
                  child: Text(
                    '$year',
                    style: TextStyle(color: dropdownTextColor),
                  ),
                );
              }),
              onChanged: (val) {
                setState(() => selectedYear = val!);
                _fetchTabData();
              },
              iconEnabledColor: dropdownTextColor,
              iconDisabledColor: dropdownTextColor,
              underline: const SizedBox(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[100],
        title: const Text('Analytics'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.purple[100],
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.purple[300],
              indicatorColor: Colors.deepPurple,
              indicatorWeight: 3.2,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: const [
                Tab(text: "Daily Trend"),
                Tab(text: "Emotions"),
                Tab(text: "Time of Day"),
                Tab(text: "Monthly"),
              ],
            ),
          ),
          if (_tabController.index == 0 || _tabController.index == 1)
            _buildMonthSelector(),
          // No selector for "Time of Day"
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: _buildAnimatedTabContent(),
            ),
          ),
        ],
      ),
    );
  }
}
