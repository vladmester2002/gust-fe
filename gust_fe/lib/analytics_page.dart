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
import 'package:path_provider/path_provider.dart'; // Only for mobile/desktop
import 'package:open_file/open_file.dart'; // Only for mobile/desktop

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
      // Web download - simplified without dart:html
      // Note: Full web download functionality requires dart:html which can't be imported in mobile builds
      // You can enable this in a web-specific file if needed
      throw UnsupportedError('CSV download on web requires dart:html - use mobile app for downloads');
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
    bool showExportButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF6A1B9A).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF6A1B9A).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6A1B9A),
                        Color(0xFF8E24AA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A1B9A).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2D1B47),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showExportButton)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _downloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF6A1B9A),
                              ))
                          : const Icon(Icons.download_rounded, size: 20),
                      color: const Color(0xFF6A1B9A),
                      tooltip: "Export CSV",
                      onPressed: _downloading ? null : _exportCsv,
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: const Color(0xFF6A1B9A),
                    tooltip: "Refresh",
                    onPressed: onRefresh,
                  ),
                ),
              ],
            ),
            
            // Stats Cards
            if (stats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: stats,
                ),
              ),
            
            const SizedBox(height: 12),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<AnalyticsResponse> data) {
    final sortedData = _sortDataByDate(data);
    double rawMaxY = sortedData.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev);
    double maxY = getCleanMaxY(rawMaxY);
    int yStep = getYAxisStep(maxY);

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF6A1B9A),
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final resp = sortedData[group.x.toInt()];
                String displayDate = resp.label ?? '';
                if (displayDate.contains('-')) {
                  try {
                    final dt = DateTime.parse(displayDate);
                    displayDate = DateFormat('EEE, MMM d').format(dt);
                  } catch (_) {}
                }
                return BarTooltipItem(
                  '$displayDate\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${resp.value.toStringAsFixed(1)}g',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
            touchCallback: (event, res) {
              if (event is FlTapUpEvent && res != null && res.spot != null) {
                final idx = res.spot!.touchedBarGroupIndex;
                if (idx >= 0 && idx < sortedData.length) {
                  final resp = sortedData[idx];
                  _showDetailSheet(resp, sortedData);
                }
              }
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: sortedData.length > 15 ? (sortedData.length / 7).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= sortedData.length) return const SizedBox();
                  
                  // For large datasets, only show every nth label
                  if (sortedData.length > 15) {
                    final interval = (sortedData.length / 7).ceil();
                    if (idx % interval != 0 && idx != sortedData.length - 1) {
                      return const SizedBox();
                    }
                  }
                  
                  final dateStr = sortedData[idx].label;
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final isToday = dateStr != null && dateStr.contains(today);
                  
                  String dayLabel = '';
                  String dateLabel = '';
                  
                  if (dateStr != null && dateStr.contains('-')) {
                    try {
                      final dt = DateTime.parse(dateStr);
                      dayLabel = DateFormat('EEE').format(dt);
                      dateLabel = DateFormat('d').format(dt);
                    } catch (_) {
                      dayLabel = dateStr;
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? const Color(0xFFFF9800) : const Color(0xFF6A1B9A),
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: isToday ? const Color(0xFFFF9800) : const Color(0xFF6A1B9A).withOpacity(0.6),
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
                interval: yStep.toDouble(),
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}g',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6A1B9A),
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
            horizontalInterval: yStep.toDouble(),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(sortedData.length, (index) {
            final dateStr = sortedData[index].label;
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final isToday = dateStr != null && dateStr.contains(today);
            final value = sortedData[index].value;
            
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: sortedData.length > 20 ? 12 : (sortedData.length > 10 ? 18 : 24),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                    bottom: Radius.circular(2),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isToday
                        ? [
                            const Color(0xFFFF9800),
                            const Color(0xFFFFA726),
                          ]
                        : [
                            const Color(0xFF6A1B9A),
                            const Color(0xFF8E24AA),
                            const Color(0xFFAB47BC),
                          ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: const Color(0xFF6A1B9A).withOpacity(0.08),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<AnalyticsResponse> data, String xLabel) {
    List<AnalyticsResponse> sortedData;
    if (xLabel == "Time") {
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

    return Container(
      height: 300,
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF6A1B9A),
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipBorder: BorderSide.none,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final resp = sortedData[group.x.toInt()];
                final label = resp.label ?? '';
                final emoji = getEmotionEmoji(label);
                return BarTooltipItem(
                  "$emoji $label\n",
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: "${resp.value.toStringAsFixed(1)} grams",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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
                    width: 22,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF6A1B9A),
                        const Color(0xFF8E24AA),
                        const Color(0xFFAB47BC),
                      ],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: const Color(0xFF6A1B9A).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 95,
                interval: 1,
                getTitlesWidget: (value, _) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= sortedData.length) return const SizedBox();
                  final slot = sortedData[idx].label ?? '';
                  final emoji = getEmotionEmoji(slot);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 1),
                        Transform.rotate(
                          angle: -0.2,
                          child: Text(
                            slot.length > 9 ? '${slot.substring(0, 9)}...' : slot,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.w600,
                            ),
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
                reservedSize: 42,
                interval: yStep.toDouble(),
                getTitlesWidget: (value, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}g',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6A1B9A),
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
            horizontalInterval: yStep.toDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFF6A1B9A).withOpacity(0.08),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildEmotionSummary(List<AnalyticsResponse> data) {
    // Sort by value descending to show most frequent first
    final sortedData = List<AnalyticsResponse>.from(data)
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedData.length,
      itemBuilder: (context, idx) {
        final e = sortedData[idx];
        final emoji = getEmotionEmoji(e.label);
        final maxCount = sortedData.first.value;
        final percentage = (e.value / maxCount * 100).toInt();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A1B9A).withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showDetailSheet(e, data),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: idx == 0
                              ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                              : [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Emoji
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Label and progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.label ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF2D1B47),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                idx == 0 ? const Color(0xFFFFD700) : const Color(0xFF6A1B9A),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6A1B9A).withOpacity(0.1),
                            const Color(0xFF8E24AA).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6A1B9A).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        "${e.value.toStringAsFixed(0)}×",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6A1B9A).withOpacity(0.08),
            const Color(0xFF8E24AA).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6A1B9A).withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji, style: const TextStyle(fontSize: 22)),
          if (emoji != null) const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF6A1B9A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.purple[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final emoji = [
      "📉", "🦄", "📊", "🤷‍♂️", "☁️", "🥲"
    ]..shuffle();
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFF6A1B9A).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji.first, style: const TextStyle(fontSize: 60)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No data for this period',
              style: TextStyle(
                color: Color(0xFF6A1B9A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging to see your analytics',
              style: TextStyle(
                color: Colors.purple[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed: _fetchTabData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.red.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Text("❌", style: TextStyle(fontSize: 54)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed: _fetchTabData,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(AnalyticsResponse resp, List<AnalyticsResponse> allData) async {
    if (_modalOpen) return;
    _modalOpen = true;

    double? minVal, maxVal, avgVal, sumVal;
    if (allData.isNotEmpty) {
      minVal = allData.map((e) => e.value).reduce(min);
      maxVal = allData.map((e) => e.value).reduce(max);
      avgVal = allData.map((e) => e.value).reduce((a, b) => a + b) / allData.length;
      sumVal = allData.map((e) => e.value).reduce((a, b) => a + b);
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6A1B9A).withOpacity(0.1),
            const Color(0xFF8E24AA).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6A1B9A).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: Color(0xFF6A1B9A),
            size: 22,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButton<int>(
              value: selectedMonth,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: Color(0xFF6A1B9A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              items: List.generate(12, (i) {
                return DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(2000, i + 1)),
                  ),
                );
              }),
              onChanged: (val) {
                setState(() => selectedMonth = val!);
                _fetchTabData();
              },
              iconEnabledColor: const Color(0xFF6A1B9A),
              underline: const SizedBox(),
              isDense: true,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButton<int>(
              value: selectedYear,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: Color(0xFF6A1B9A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              items: List.generate(5, (i) {
                final year = DateTime.now().year - i;
                return DropdownMenuItem(
                  value: year,
                  child: Text('$year'),
                );
              }),
              onChanged: (val) {
                setState(() => selectedYear = val!);
                _fetchTabData();
              },
              iconEnabledColor: const Color(0xFF6A1B9A),
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
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6A1B9A),
                Color(0xFF8E24AA),
                Color(0xFFAB47BC),
              ],
            ),
          ),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A1B9A),
                  Color(0xFF8E24AA),
                  Color(0xFFAB47BC),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: "Daily"),
                Tab(text: "Emotions"),
                Tab(text: "Time"),
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
