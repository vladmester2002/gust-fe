import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'emotion.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:provider/provider.dart';
import 'services/partner_access_api.dart';
import 'state/auth_state.dart';
import 'services/auth_helper.dart';
import 'services/connectivity_service.dart';
import 'services/local_analytics_service.dart';
import 'data/local/gust_database.dart';
import 'repositories/auth_repository.dart';
import 'services/api_service.dart';

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
  "Afternoon": "🏙️",
  "Evening": "🌆",
  "Night": "🌃",
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
  final int? initialOwnerId;
  final String? initialOwnerName;
  final bool embedInNavigation;
  const AnalyticsPage({
    super.key,
    required this.logs,
    this.initialOwnerId,
    this.initialOwnerName,
    this.embedInNavigation = true,
  });

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
  double _dailyGoal = 75.0;

  bool _downloading = false;
  
  // New flexible analytics controls
  String _viewMode = 'overall'; // 'overall', 'emotions', 'timeOfDay'
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final PartnerAccessApi _partnerApi = const PartnerAccessApi();
  List<PartnerAccessEntry> _analyticsOwners = [];
  int? _selectedOwnerId;
  String? _selectedOwnerName;
  bool _loadingPartnerOwners = false;

  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _selectedOwnerId = widget.initialOwnerId;
    _selectedOwnerName = widget.initialOwnerName;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadDailyGoal();
    // Load initial data with custom date range (last 30 days by default)
    _fetchCustomData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPartnerAssignments());

    // Listen for connectivity restoration to retry fetching data
    _connectivitySub = ConnectivityService.instance.onConnectivityRestored.listen((_) {
      print('AnalyticsPage: Connectivity restored, refreshing data...');
      if (mounted) {
        _fetchTabData();
        _loadPartnerAssignments();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  // Fetch data based on custom date range and view mode
  Future<void> _fetchCustomData() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
    });
    
    final token = await _getToken();
    
    // OFFLINE FALLBACK LOGIC
    if (token == null || ApiService.instance.isOfflineSync) {
      print('AnalyticsPage: Offline mode or no token, using local data');
      await _fetchLocalCustomData();
      setState(() => _loading = false);
      return;
    }

    try {
      if (_viewMode == 'overall') {
        // For overall view, fetch daily data for each month in the range
        await _fetchDailyDataForRange(token);
      } else if (_viewMode == 'emotions') {
        // For emotions, aggregate emotion data across the date range
        await _fetchEmotionDataForRange(token);
      } else if (_viewMode == 'timeOfDay') {
        // For time of day, aggregate time patterns across the date range
        await _fetchTimeDataForRange(token);
      }
    } catch (e) {
      print('AnalyticsPage: API error ($e), falling back to local data');
      await _fetchLocalCustomData();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchLocalCustomData() async {
    try {
      final user = await AuthRepository().getActiveUser();
      if (user?.id == null) {
        setState(() => _error = 'Not authenticated');
        return;
      }

      // Fetch all logs for the user
      // Note: We might want to optimize this to fetch only needed range if DB supports it,
      // but fetchLogs gets everything currently.
      final allLogs = await GustDatabase.instance.fetchLogs(userId: user!.id!);
      
      // Filter by date range
      final filteredLogs = allLogs.where((log) {
        // Reset time part for accurate date comparison
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
        return !logDate.isBefore(start) && !logDate.isAfter(end);
      }).toList();

      List<AnalyticsResponse> result = [];

      if (_viewMode == 'overall') {
        // We need to group by day across the range
        // Reuse the logic from LocalAnalyticsService but adapted for a range
        // Actually, computeDailyTrend is per month.
        // Let's just group manually here or add a range method to service.
        // For simplicity, let's group here using the filtered logs.
        final Map<String, double> dailyTotals = {};
        for (final log in filteredLogs) {
           final dateKey = log.date.toIso8601String().substring(0, 10);
           dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + log.sugarGrams;
        }
        result = dailyTotals.entries.map((e) => AnalyticsResponse(
          label: e.key,
          value: e.value,
        )).toList();

      } else if (_viewMode == 'emotions') {
        // Reuse service logic? computeEmotionSummary is per month.
        // Let's compute for the filtered range directly.
        final Map<String, double> emotionTotals = {};
        final Map<String, int> emotionCounts = {};

        for (final log in filteredLogs) {
          final emotion = log.emotion;
          emotionTotals[emotion] = (emotionTotals[emotion] ?? 0) + log.sugarGrams;
          emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
        }

        result = emotionTotals.entries.map((entry) {
          final emotion = entry.key;
          final totalSugar = entry.value;
          final count = emotionCounts[emotion] ?? 1;
          final average = totalSugar / count;

          return AnalyticsResponse(
            label: emotion,
            value: totalSugar,
            detail: 'Avg: ${average.toStringAsFixed(1)}g per time | ${count}x logged',
          );
        }).toList();

      } else if (_viewMode == 'timeOfDay') {
        result = LocalAnalyticsService.computeTimeOfDayPattern(filteredLogs);
      }

      setState(() {
        _data = result;
        _error = null; // Clear error if local fetch succeeds
      });

    } catch (e) {
      setState(() => _error = 'Failed to load local data: $e');
    }
  }

  String _slotForHour(int hour) {
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 22) return 'Evening';
    return 'Night';
  }
  
  // Fetch daily data across the date range
  Future<void> _fetchDailyDataForRange(String token) async {
    List<AnalyticsResponse> allData = [];
    
    // Calculate months to fetch
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    DateTime end = DateTime(_endDate.year, _endDate.month, 1);
    
    while (current.isBefore(end.add(const Duration(days: 1)))) {
      try {
        final query = {
          'month': current.month.toString(),
          'year': current.year.toString(),
          if (_selectedOwnerId != null) 'ownerId': _selectedOwnerId!.toString(),
        };
        final uri = Uri.parse('$baseUrl/api/analytics/daily-trend')
            .replace(queryParameters: query);
        
        final resp = await http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
        
        if (resp.statusCode == 200) {
          final List raw = jsonDecode(resp.body);
          final monthData = raw.map((e) => AnalyticsResponse.fromJson(e)).toList();
          allData.addAll(monthData);
        }
      } catch (e) {
        // Continue with other months even if one fails
      }
      
      // Move to next month
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    // Filter data to only include dates within the selected range
    final filteredData = allData.where((item) {
      try {
        final itemDate = DateTime.parse(item.label ?? '');
        return !itemDate.isBefore(_startDate) && 
               !itemDate.isAfter(_endDate.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
    
    setState(() {
      _data = filteredData;
    });
  }
  
  // Fetch and aggregate emotion data for range
  Future<void> _fetchEmotionDataForRange(String token) async {
    Map<String, double> emotionTotals = {};
    Map<String, int> emotionCounts = {}; // Track number of occurrences
    
    // Calculate months to fetch
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    DateTime end = DateTime(_endDate.year, _endDate.month, 1);
    
    while (current.isBefore(end.add(const Duration(days: 1)))) {
      try {
        final query = {
          'month': current.month.toString(),
          'year': current.year.toString(),
          if (_selectedOwnerId != null) 'ownerId': _selectedOwnerId!.toString(),
        };
        final uri = Uri.parse('$baseUrl/api/analytics/emotion-summary')
            .replace(queryParameters: query);
        
        final resp = await http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
        
        if (resp.statusCode == 200) {
          final List raw = jsonDecode(resp.body);
          for (var item in raw) {
            final emotion = item['label'] ?? 'Unknown';
            final value = (item['value'] is int) 
              ? (item['value'] as int).toDouble() 
              : (item['value'] ?? 0.0).toDouble();
            
            emotionTotals[emotion] = (emotionTotals[emotion] ?? 0.0) + value;
            emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
          }
        }
      } catch (e) {
        // Continue with other months
      }
      
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    // Convert to list with average calculation and additional detail
    final dataList = emotionTotals.entries.map((e) {
      final count = emotionCounts[e.key] ?? 1;
      final average = e.value / count;
      final total = e.value;
      
      return AnalyticsResponse(
        label: e.key,
        value: total, // Show total for now, but we'll display average in tooltip
        detail: 'Avg: ${average.toStringAsFixed(1)}g per time | ${count}x logged',
      );
    }).toList();
    
    setState(() {
      _data = dataList;
    });
  }
  
  // Fetch and aggregate time of day data for range
  Future<void> _fetchTimeDataForRange(String token) async {
    Map<String, double> timeTotals = {};
    Map<String, int> timeCounts = {}; // Track number of days with logs in this time
    
    // Fetch data for each day in the range
    DateTime current = _startDate;
    
    while (!current.isAfter(_endDate)) {
      try {
        final query = {
          'date': DateFormat('yyyy-MM-dd').format(current),
          if (_selectedOwnerId != null) 'ownerId': _selectedOwnerId!.toString(),
        };
        final uri = Uri.parse('$baseUrl/api/analytics/time-of-day-pattern')
            .replace(queryParameters: query);
        
        final resp = await http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
        
        if (resp.statusCode == 200) {
          final List raw = jsonDecode(resp.body);
          
          for (var item in raw) {
            final timeSlot = item['label'] ?? 'Unknown';
            final value = (item['value'] is int) 
              ? (item['value'] as int).toDouble() 
              : (item['value'] ?? 0.0).toDouble();
            
            if (value > 0) {
              timeTotals[timeSlot] = (timeTotals[timeSlot] ?? 0.0) + value;
              timeCounts[timeSlot] = (timeCounts[timeSlot] ?? 0) + 1;
            }
          }
        }
      } catch (e) {
        // Continue with other days
      }
      
      current = current.add(const Duration(days: 1));
    }
    
    // Convert to list with average per day calculation
    final dataList = timeTotals.entries.map((e) {
      final daysWithData = timeCounts[e.key] ?? 1;
      final avgPerDay = e.value / daysWithData;
      final total = e.value;
      
      return AnalyticsResponse(
        label: e.key,
        value: total, // Total for the period
        detail: 'Avg: ${avgPerDay.toStringAsFixed(1)}g per day | $daysWithData days',
      );
    }).toList();
    
    setState(() {
      _data = dataList;
    });
  }
  
  Future<void> _loadDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyGoal = prefs.getDouble('dailySugarGoal') ?? 75.0;
    });
  }

  Future<void> _loadPartnerAssignments() async {
    if (!mounted) return;
    final authState = context.read<AuthState?>();
    final role = authState?.currentUser?.role ?? '';
    final email = authState?.currentUser?.email;
    if (email == null || role.toUpperCase() != 'PARTNER') {
      return;
    }
    setState(() => _loadingPartnerOwners = true);
    try {
      final assignments = await _partnerApi.assignmentsForModule('ANALYTICS');
      if (!mounted) return;
      setState(() {
        _analyticsOwners = assignments;
      });
    } catch (_) {
      // ignore errors in optional filter loading
    } finally {
      if (mounted) {
        setState(() => _loadingPartnerOwners = false);
      }
    }
  }

  void _applyOwnerSelection(int? ownerId, String? ownerName) {
    setState(() {
      _selectedOwnerId = ownerId;
      _selectedOwnerName = ownerName;
    });
    _fetchCustomData();
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

  Future<String?> _getToken() => AuthHelper.getNetworkToken();

  // ------ CSV EXPORT BUTTON FUNCTIONALITY ---------
  Future<void> _exportCsv() async {
  setState(() {
    _downloading = true;
  });
  try {
    if (_selectedOwnerId != null) {
      throw Exception('CSV export is only available for your own analytics.');
    }
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
    
    // OFFLINE FALLBACK LOGIC
    if (token == null || ApiService.instance.isOfflineSync) {
      print('AnalyticsPage: Offline mode or no token, using local data for tab');
      await _fetchLocalTabData();
      setState(() {
        _loading = false;
        _showContent = true;
      });
      return;
    }

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
    if (_selectedOwnerId != null) {
      params['ownerId'] = _selectedOwnerId!.toString();
    }
    final query = params.isEmpty ? null : params;
    try {
      final uri =
          Uri.parse('$baseUrl$endpoint').replace(queryParameters: query);
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
      print('AnalyticsPage: API error ($e), falling back to local data for tab');
      await _fetchLocalTabData();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _showContent = true;
        });
      }
    }
  }

  Future<void> _fetchLocalTabData() async {
    try {
      final user = await AuthRepository().getActiveUser();
      if (user?.id == null) {
        setState(() => _error = 'Not authenticated');
        return;
      }

      final allLogs = await GustDatabase.instance.fetchLogs(userId: user!.id!);
      List<AnalyticsResponse> result = [];

      switch (_tabController.index) {
        case 0: // Daily Trend
          result = LocalAnalyticsService.computeDailyTrend(allLogs, selectedMonth, selectedYear);
          break;
        case 1: // Emotion Summary
          result = LocalAnalyticsService.computeEmotionSummary(allLogs, selectedMonth, selectedYear);
          break;
        case 2: // Time of Day (Today)
          // Filter for just today
          final todayLogs = allLogs.where((log) => 
            log.date.year == _currentDay.year &&
            log.date.month == _currentDay.month &&
            log.date.day == _currentDay.day
          ).toList();
          result = LocalAnalyticsService.computeTimeOfDayPattern(todayLogs);
          break;
        case 3: // Monthly Total
          result = LocalAnalyticsService.computeMonthlyTotal(allLogs);
          break;
      }

      setState(() {
        _data = result;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load local data: $e');
    }
  }
  
  // Fetch emotions data for dashboard card
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
            
            // Stats Cards - Horizontal Scrollable
            if (stats.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 14, bottom: 10),
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stats.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => stats[index],
                  physics: const BouncingScrollPhysics(),
                ),
              ),
            
            const SizedBox(height: 6),
            chart,
            
            // Helpful hint for users
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tap any bar for detailed insights',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<AnalyticsResponse> data) {
    final sortedData = _sortDataByDate(data);
    
    if (sortedData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    double rawMaxY = sortedData.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev);
    double maxY = getCleanMaxY(rawMaxY);

    // Create line chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedData.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedData[i].value));
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.only(right: 12, top: 12, left: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xFF6A1B9A),
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final resp = sortedData[spot.x.toInt()];
                  String displayDate = resp.label ?? '';
                  String relativeDay = '';
                  
                  if (displayDate.contains('-')) {
                    try {
                      final dt = DateTime.parse(displayDate);
                      displayDate = DateFormat('MMM d').format(dt);
                      
                      final today = DateTime.now();
                      final dateOnly = DateTime(dt.year, dt.month, dt.day);
                      final todayOnly = DateTime(today.year, today.month, today.day);
                      
                      if (dateOnly == todayOnly) {
                        relativeDay = ' (Today)';
                      } else if (dateOnly == todayOnly.subtract(const Duration(days: 1))) {
                        relativeDay = ' (Yesterday)';
                      }
                    } catch (_) {}
                  }
                  
                  final dailyGoal = _dailyGoal;
                  String goalIndicator = '';
                  if (resp.value <= dailyGoal * 0.8) {
                    goalIndicator = '\n✓ Well below';
                  } else if (resp.value <= dailyGoal) {
                    goalIndicator = '\n✓ On track';
                  } else if (resp.value <= dailyGoal * 1.2) {
                    goalIndicator = '\n⚠ Slightly over';
                  } else {
                    goalIndicator = '\n⚠ Over goal';
                  }
                  
                  return LineTooltipItem(
                    '$displayDate$relativeDay\n${resp.value.toStringAsFixed(1)}g$goalIndicator',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
                final spot = response.lineBarSpots!.first;
                final idx = spot.x.toInt();
                if (idx >= 0 && idx < sortedData.length) {
                  _showDetailSheet(sortedData[idx], sortedData);
                }
              }
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: sortedData.length > 15 ? (sortedData.length / 7).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sortedData.length) return const SizedBox();
                  
                  try {
                    final date = DateTime.parse(sortedData[idx].label ?? '');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM d').format(date),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D1B47),
                        ),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox();
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}g',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF6A1B9A),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF6A1B9A),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.2),
                    const Color(0xFF6A1B9A).withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              // Show goal line
              aboveBarData: BarAreaData(show: false),
            ),
          ],
          // Add goal reference line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: _dailyGoal,
                color: Colors.orange.withOpacity(0.5),
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (line) => 'Goal: ${_dailyGoal.toInt()}g',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Old bar chart version (keeping for reference in tabs)
  Widget _buildBarChartVersion(List<AnalyticsResponse> data) {
    final sortedData = _sortDataByDate(data);
    double rawMaxY = sortedData.map((e) => e.value).fold(0.0, (prev, el) => el > prev ? el : prev);
    double maxY = getCleanMaxY(rawMaxY);
    int yStep = getYAxisStep(maxY);

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 2),
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
                String relativeDay = '';
                if (displayDate.contains('-')) {
                  try {
                    final dt = DateTime.parse(displayDate);
                    displayDate = DateFormat('EEE, MMM d').format(dt);
                    
                    final today = DateTime.now();
                    final dateOnly = DateTime(dt.year, dt.month, dt.day);
                    final todayOnly = DateTime(today.year, today.month, today.day);
                    
                    if (dateOnly == todayOnly) {
                      relativeDay = ' (Today)';
                    } else if (dateOnly == todayOnly.subtract(const Duration(days: 1))) {
                      relativeDay = ' (Yesterday)';
                    }
                  } catch (_) {}
                }
                
                // Get user's daily goal for comparison
                final dailyGoal = _dailyGoal;
                final goalDiff = resp.value - dailyGoal;
                String goalIndicator = '';
                if (resp.value <= dailyGoal * 0.8) {
                  goalIndicator = '\n✓ Well below goal';
                } else if (resp.value <= dailyGoal) {
                  goalIndicator = '\n✓ Within goal';
                } else if (resp.value <= dailyGoal * 1.2) {
                  goalIndicator = '\n⚠ Slightly over';
                } else {
                  goalIndicator = '\n⚠ Over goal';
                }
                
                return BarTooltipItem(
                  '$displayDate$relativeDay\n',
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
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    TextSpan(
                      text: goalIndicator,
                      style: TextStyle(
                        color: goalDiff <= 0 ? Colors.lightGreenAccent : Colors.orangeAccent[100],
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
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
                reservedSize: 32,
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
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: isToday ? const Color(0xFFFF9800) : const Color(0xFF6A1B9A),
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 0.5),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 7,
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
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

    return Column(
      children: [
        // Bar Chart without bottom labels
        Container(
          height: 240,
          padding: const EdgeInsets.all(16),
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
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final resp = sortedData[group.x.toInt()];
                    final label = resp.label ?? '';
                    final emoji = getEmotionEmoji(label);
                    return BarTooltipItem(
                      "$emoji $label\n",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: "${resp.value.toStringAsFixed(1)}g",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
                    _showDetailSheet(sortedData[idx], sortedData);
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
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xFF6A1B9A),
                            Color(0xFF8E24AA),
                            Color(0xFFAB47BC),
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
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yStep.toDouble(),
                    getTitlesWidget: (value, _) {
                      return Text(
                        '${value.toInt()}g',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yStep.toDouble(),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Labels below chart as separate chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: sortedData.asMap().entries.map((entry) {
            final data = entry.value;
            final label = data.label ?? '';
            final emoji = getEmotionEmoji(label);
            return InkWell(
              onTap: () => _showDetailSheet(data, sortedData),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6A1B9A).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A1B9A).withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data.value.toStringAsFixed(1)}g',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6A1B9A).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(minHeight: 68),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rank badge
                    Container(
                      width: 28,
                      height: 28,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Emoji
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 10),
                    // Label and progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.label ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF2D1B47),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
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
                    const SizedBox(width: 10),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6A1B9A).withOpacity(0.1),
                            const Color(0xFF8E24AA).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF6A1B9A).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "${e.value.toStringAsFixed(0)}×",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
    final total = values.reduce((a, b) => a + b);
    final daysTracked = data.length;
    
    // Calculate goal achievement
    int daysWithinGoal = 0;
    for (var value in values) {
      if (value <= _dailyGoal) daysWithinGoal++;
    }
    final goalRate = (daysWithinGoal / daysTracked * 100).round();
    
    return [
      _buildStatTile("$daysTracked Days", "${avg.toStringAsFixed(1)}g", subtitle: "Daily Avg"),
      _buildStatTile("$goalRate% On Track", "${total.toStringAsFixed(0)}g", subtitle: "Total Sugar"),
      _buildStatTile("Best Day", "${minValue.toStringAsFixed(1)}g", subtitle: "Lowest"),
      _buildStatTile("Worst Day", "${maxValue.toStringAsFixed(1)}g", subtitle: "Highest"),
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

  Widget _buildStatTile(String label, String value, {String? emoji, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.purple[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF6A1B9A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

    // Get user's daily sugar goal from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final dailyGoal = prefs.getDouble('dailySugarGoal') ?? 75.0;

    double? minVal, maxVal, avgVal;
    if (allData.isNotEmpty) {
      minVal = allData.map((e) => e.value).reduce(min);
      maxVal = allData.map((e) => e.value).reduce(max);
      avgVal = allData.map((e) => e.value).reduce((a, b) => a + b) / allData.length;
    }

    String? prettyDate;
    String? relativeDay;
    try {
      if (resp.label != null && resp.label!.contains('-')) {
        final date = DateTime.parse(resp.label!);
        prettyDate = DateFormat('EEEE, MMMM d, y').format(date);
        
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final todayOnly = DateTime(today.year, today.month, today.day);
        final yesterdayOnly = DateTime(yesterday.year, yesterday.month, yesterday.day);
        
        if (dateOnly == todayOnly) {
          relativeDay = "Today";
        } else if (dateOnly == yesterdayOnly) {
          relativeDay = "Yesterday";
        } else {
          final diff = todayOnly.difference(dateOnly).inDays;
          if (diff > 0 && diff <= 7) {
            relativeDay = "$diff days ago";
          } else if (diff < 0 && diff >= -7) {
            relativeDay = "In ${-diff} days";
          }
        }
      }
    } catch (_) {}

    // Calculate goal comparison
    final goalDifference = resp.value - dailyGoal;
    final goalPercentage = (resp.value / dailyGoal * 100);
    String goalStatus = "";
    Color goalStatusColor = Colors.green;
    IconData goalStatusIcon = Icons.check_circle;
    
    if (resp.value <= dailyGoal * 0.8) {
      goalStatus = "Well below goal! 🎉";
      goalStatusColor = const Color(0xFF4CAF50);
      goalStatusIcon = Icons.celebration;
    } else if (resp.value <= dailyGoal) {
      goalStatus = "Within goal ✓";
      goalStatusColor = const Color(0xFF66BB6A);
      goalStatusIcon = Icons.check_circle;
    } else if (resp.value <= dailyGoal * 1.2) {
      goalStatus = "Slightly over goal";
      goalStatusColor = const Color(0xFFFF9800);
      goalStatusIcon = Icons.warning_amber;
    } else {
      goalStatus = "Over goal";
      goalStatusColor = const Color(0xFFF44336);
      goalStatusIcon = Icons.error;
    }

    // Calculate trend (if there's previous data)
    String? trendInfo;
    IconData? trendIcon;
    Color? trendColor;
    if (allData.length > 1) {
      final currentIndex = allData.indexWhere((e) => e.label == resp.label);
      if (currentIndex > 0) {
        final previousValue = allData[currentIndex - 1].value;
        final change = resp.value - previousValue;
        final changePercent = (change / previousValue * 100).abs();
        
        if (change > 0) {
          trendInfo = "↗️ Up ${change.toStringAsFixed(1)}g (${changePercent.toStringAsFixed(0)}%) from previous day";
          trendIcon = Icons.trending_up;
          trendColor = Colors.red[600];
        } else if (change < 0) {
          trendInfo = "↘️ Down ${change.abs().toStringAsFixed(1)}g (${changePercent.toStringAsFixed(0)}%) from previous day";
          trendIcon = Icons.trending_down;
          trendColor = Colors.green[600];
        } else {
          trendInfo = "→ Same as previous day";
          trendIcon = Icons.trending_flat;
          trendColor = Colors.grey[600];
        }
      }
    }

    String percentageOfAvg = "";
    if (avgVal != null && avgVal > 0) {
      percentageOfAvg = "${((resp.value / avgVal) * 100).toStringAsFixed(0)}% of period average";
    }

    String contextMessage = "";
    Color contextColor = Colors.purple;
    if (avgVal != null) {
      if (resp.value >= avgVal * 1.25) {
        contextMessage = "📈 Significantly above your average";
        contextColor = Colors.red[700]!;
      } else if (resp.value <= avgVal * 0.75) {
        contextMessage = "📉 Significantly below your average";
        contextColor = Colors.green[700]!;
      } else if (resp.value > avgVal) {
        contextMessage = "↗️ Slightly above your average";
        contextColor = Colors.orange[700]!;
      } else if (resp.value < avgVal) {
        contextMessage = "↘️ Slightly below your average";
        contextColor = Colors.blue[700]!;
      } else {
        contextMessage = "➡️ Right at your average";
        contextColor = Colors.purple[700]!;
      }
    }

    bool isMax = (maxVal != null && resp.value == maxVal);
    bool isMin = (minVal != null && resp.value == minVal);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.only(top: 80),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Date header with relative day
                  if (prettyDate != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (relativeDay != null)
                                Text(
                                  relativeDay,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: relativeDay == "Today" 
                                        ? const Color(0xFFFF9800)
                                        : const Color(0xFF6A1B9A),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                prettyDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isMax || isMin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMax ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMax ? Colors.red[200]! : Colors.green[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMax ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isMax ? Colors.red[700] : Colors.green[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMax ? "Highest" : "Lowest",
                                  style: TextStyle(
                                    color: isMax ? Colors.red[700] : Colors.green[700],
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Main value display
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        color: const Color(0xFF6A1B9A).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              resp.value.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6A1B9A),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "grams",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Sugar Intake",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Goal comparison
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: goalStatusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: goalStatusColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(goalStatusIcon, color: goalStatusColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goalStatus,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: goalStatusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "Goal: ${dailyGoal.toStringAsFixed(0)}g",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${goalDifference >= 0 ? '+' : ''}${goalDifference.toStringAsFixed(1)}g",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: goalDifference <= 0 ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "(${goalPercentage.toStringAsFixed(0)}%)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Trend information
                  if (trendInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: trendColor?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: trendColor?.withOpacity(0.3) ?? Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(trendIcon, color: trendColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              trendInfo,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Context message (comparison to average)
                  if (contextMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: contextColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: contextColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contextMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: contextColor,
                                  ),
                                ),
                                if (percentageOfAvg.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    percentageOfAvg,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Period statistics
                  if (minVal != null && maxVal != null && avgVal != null) ...[
                    const Divider(height: 32),
                    Text(
                      "Period Statistics",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            "Lowest",
                            "${minVal.toStringAsFixed(1)}g",
                            Icons.south,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            "Average",
                            "${avgVal.toStringAsFixed(1)}g",
                            Icons.show_chart,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            "Highest",
                            "${maxVal.toStringAsFixed(1)}g",
                            Icons.north,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
    _modalOpen = false;
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMonthSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(12),
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
  
  // New flexible control panel
  Widget _buildFlexibleControlPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFF6A1B9A).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View Mode Selector
            const Text(
              '📊 View Mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D1B47),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildViewModeChip('overall', 'Overall Intake', Icons.show_chart),
                _buildViewModeChip('emotions', 'By Emotions', Icons.emoji_emotions),
                _buildViewModeChip('timeOfDay', 'By Time of Day', Icons.access_time),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Date Range Selector
            const Text(
              '📅 Time Period',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D1B47),
              ),
            ),
            const SizedBox(height: 12),
            
            // Quick date range buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickDateButton('Today', 0),
                _buildQuickDateButton('Last 7 Days', 7),
                _buildQuickDateButton('Last 30 Days', 30),
                _buildQuickDateButton('This Year', -1),
              ],
            ),
            const SizedBox(height: 12),
            
            // Custom date pickers
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerButton(
                    'From',
                    _startDate,
                    (date) {
                      setState(() {
                        _startDate = date;
                        if (_startDate.isAfter(_endDate)) {
                          _endDate = _startDate;
                        }
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Color(0xFF6A1B9A), size: 20),
                ),
                Expanded(
                  child: _buildDatePickerButton(
                    'To',
                    _endDate,
                    (date) {
                      setState(() {
                        _endDate = date;
                        if (_endDate.isBefore(_startDate)) {
                          _startDate = _endDate;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _fetchCustomData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Chart',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildViewModeChip(String mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF6A1B9A),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2D1B47),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickDateButton(String label, int days) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          if (days == 0) {
            // Today only
            _startDate = DateTime.now();
            _endDate = DateTime.now();
          } else if (days == -1) {
            // This year
            _endDate = DateTime.now();
            _startDate = DateTime(_endDate.year, 1, 1);
          } else {
            // Last N days
            _endDate = DateTime.now();
            _startDate = _endDate.subtract(Duration(days: days));
          }
        });
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6A1B9A),
        side: const BorderSide(color: Color(0xFF6A1B9A)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildDatePickerButton(String label, DateTime date, Function(DateTime) onDateSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF6A1B9A),
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF2D1B47),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6A1B9A), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, y').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D1B47),
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF6A1B9A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Flexible Control Panel - Always visible
          _buildFlexibleControlPanel(),
          
          const SizedBox(height: 12),
          
          // Show main content only if we have data
          if (_data.isNotEmpty) ...[
            // Hero Stats Card - Most Important Info At A Glance
            _buildHeroStatsCard(),
            
            const SizedBox(height: 12),
            
            // Main Chart - Adapts based on view mode
            _buildFlexibleChart(),
            
            const SizedBox(height: 12),
            
            // Quick Insights Row
            _buildQuickInsightsRow(),
            
            const SizedBox(height: 12),
          ] else if (!_loading) ...[
            // Show friendly message if no data yet
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.timeline,
                    size: 48,
                    color: Color(0xFF6A1B9A),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No data for selected period',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D1B47),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try selecting a different time period or view mode',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildHeroStatsCard() {
    final values = _data.map((e) => e.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final daysTracked = _data.length;
    int daysWithinGoal = 0;
    for (var value in values) {
      if (value <= _dailyGoal) daysWithinGoal++;
    }
    final goalRate = (daysWithinGoal / daysTracked * 100).round();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            goalRate >= 70 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
            goalRate >= 70 ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (goalRate >= 70 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
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
                      '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _viewMode == 'overall' 
                        ? 'Your Progress'
                        : _viewMode == 'emotions'
                          ? 'Emotional Patterns'
                          : 'Time Patterns',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goalRate >= 70 ? '🎉' : goalRate >= 50 ? '💪' : '📈',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  '$goalRate%',
                  'Days On Track',
                  Icons.check_circle_outline,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildHeroStat(
                  '${avg.toStringAsFixed(1)}g',
                  'Daily Average',
                  Icons.trending_down,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildHeroStat(
                  '$daysTracked',
                  'Days Tracked',
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeroStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  // Flexible chart that adapts to view mode
  Widget _buildFlexibleChart() {
    String title = '';
    String subtitle = '';
    IconData icon = Icons.show_chart;
    
    switch (_viewMode) {
      case 'overall':
        title = 'Sugar Intake Over Time';
        subtitle = 'Daily consumption trend';
        icon = Icons.show_chart;
        break;
      case 'emotions':
        title = 'Intake by Emotions';
        subtitle = 'How feelings affect consumption';
        icon = Icons.emoji_emotions;
        break;
      case 'timeOfDay':
        title = 'Intake by Time of Day';
        subtitle = 'When you consume most sugar';
        icon = Icons.access_time;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6A1B9A),
                  size: 20,
                ),
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
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D1B47),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 20),
                color: const Color(0xFF6A1B9A),
                onPressed: _downloading ? null : _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date range indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6A1B9A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _viewMode == 'overall' 
            ? _buildLineChart(_data)
            : _buildBarChartForViewMode(_data),
        ],
      ),
    );
  }
  
  // Bar chart for emotions and time of day views
  Widget _buildBarChartForViewMode(List<AnalyticsResponse> data) {
    // Sort by value descending for better visualization
    List<AnalyticsResponse> sortedData = List.from(data);
    sortedData.sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'No data available for this period',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    
    double maxY = sortedData.first.value;
    if (maxY == 0) maxY = 10;
    maxY = getCleanMaxY(maxY);
    int yStep = getYAxisStep(maxY);

    return Column(
      children: [
        // Chart
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
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
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final resp = sortedData[group.x.toInt()];
                    final label = resp.label ?? '';
                    final emoji = getEmotionEmoji(label);
                    return BarTooltipItem(
                      "$emoji $label\n",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: "${resp.value.toStringAsFixed(1)}g",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [
                for (int i = 0; i < sortedData.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sortedData[i].value,
                        width: 30,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xFF6A1B9A),
                            Color(0xFF8E24AA),
                            Color(0xFFAB47BC),
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
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yStep.toDouble(),
                    getTitlesWidget: (value, _) {
                      return Text(
                        '${value.toInt()}g',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yStep.toDouble(),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Labels as interactive chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: sortedData.asMap().entries.map((entry) {
            final data = entry.value;
            final label = data.label ?? '';
            final emoji = getEmotionEmoji(label);
            final rank = entry.key + 1;
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: rank == 1 
                      ? const Color(0xFFFFD700)
                      : rank == 2 
                          ? const Color(0xFFC0C0C0)
                          : rank == 3
                              ? const Color(0xFFCD7F32)
                              : const Color(0xFF6A1B9A).withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A1B9A).withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rank <= 3) ...[
                    Text(
                      rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${data.value.toStringAsFixed(1)}g',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6A1B9A).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildDailyTrendCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Color(0xFF6A1B9A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Trend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D1B47),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Tap any bar for details',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 20),
                color: const Color(0xFF6A1B9A),
                onPressed: _downloading ? null : _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLineChart(_data),
        ],
      ),
    );
  }

  Widget _buildPartnerOwnerDropdown() {
    final owners =
        _analyticsOwners.where((entry) => entry.ownerId != null).toList();
    if (_selectedOwnerId != null &&
        owners.every((entry) => entry.ownerId != _selectedOwnerId)) {
      owners.add(
        PartnerAccessEntry(
          id: _selectedOwnerId!,
          ownerId: _selectedOwnerId,
          ownerName: _selectedOwnerName ?? 'Shared partner',
          ownerEmail: '',
          partnerId: null,
          partnerName: 'You',
          partnerEmail: '',
          module: 'ANALYTICS',
          status: 'APPROVED',
        ),
      );
    }
    final bool shouldRender =
        owners.isNotEmpty || _selectedOwnerId != null || _loadingPartnerOwners;
    if (!shouldRender) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Collaborator analytics',
              filled: true,
              fillColor: const Color(0xFFF6F1FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFB39DDB), width: 1.2),
              ),
              suffixIcon: _selectedOwnerId != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      color: const Color(0xFF7E57C2),
                      tooltip: 'Back to my data',
                      onPressed: () => _applyOwnerSelection(null, null),
                    )
                  : null,
            ),
            child: _loadingPartnerOwners
                ? const LinearProgressIndicator()
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: const Text('Select collaborator'),
                      value: _selectedOwnerId,
                      items: owners.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.ownerId,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.ownerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              if ((entry.ownerEmail ?? '').isNotEmpty)
                                Text(
                                  entry.ownerEmail!,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          _applyOwnerSelection(null, null);
                        } else {
                          final match = owners.firstWhere(
                            (entry) => entry.ownerId == value,
                            orElse: () => owners.first,
                          );
                          _applyOwnerSelection(match.ownerId, match.ownerName);
                        }
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (_selectedOwnerId == null)
            Text(
              'Viewing your own analytics.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5E35B1), fontWeight: FontWeight.w600),
            )
          else
            Text(
              'Exploring insights shared by ${_selectedOwnerName ?? 'your collaborator'}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5E35B1), fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
  
  Widget _buildQuickInsightsRow() {
    final values = _data.map((e) => e.value).toList();
    final minValue = values.reduce(min);
    final total = values.reduce((a, b) => a + b);
    
    // Calculate trend
    String trendEmoji = "→";
    String trendText = "Stable";
    Color trendColor = Colors.blue;
    if (values.length >= 4) {
      final midPoint = values.length ~/ 2;
      final firstHalf = values.sublist(0, midPoint).reduce((a, b) => a + b) / midPoint;
      final secondHalf = values.sublist(midPoint).reduce((a, b) => a + b) / (values.length - midPoint);
      final change = ((secondHalf - firstHalf) / firstHalf * 100);
      
      if (change > 10) {
        trendEmoji = "📈";
        trendText = "Rising";
        trendColor = Colors.red;
      } else if (change < -10) {
        trendEmoji = "📉";
        trendText = "Improving";
        trendColor = Colors.green;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildInsightCard(
              '${minValue.toStringAsFixed(1)}g',
              'Best Day',
              Icons.star,
              Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInsightCard(
              trendText,
              'Trend',
              Icons.trending_up,
              trendColor,
              emoji: trendEmoji,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInsightCard(
              '${total.toStringAsFixed(0)}g',
              'Total',
              Icons.api,
              const Color(0xFF6A1B9A),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(String value, String label, IconData icon, Color color, {String? emoji}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          if (emoji != null)
            Text(emoji, style: const TextStyle(fontSize: 24))
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final bool showingPartner = _selectedOwnerId != null;
    final String baseName =
        showingPartner ? (_selectedOwnerName ?? 'Partner') : 'Your';
    final bool needsApostropheS =
        showingPartner ? !baseName.toLowerCase().endsWith('s') : false;
    final String titleText = showingPartner
        ? '$baseName${needsApostropheS ? '\'s' : '\''} Insight Studio'
        : 'Sugar Insight Studio';
    final String subtitleText = showingPartner
        ? 'Exploring data shared by $baseName'
        : 'Track your sugar journey';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: RefreshIndicator(
        onRefresh: _fetchCustomData,
        color: const Color(0xFF6A1B9A),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: !widget.embedInNavigation,
              leading: widget.embedInNavigation
                  ? null
                  : const BackButton(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildPartnerOwnerDropdown(),
            ),
            SliverToBoxAdapter(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    )
                  : _error != null
                      ? _buildErrorState(_error!)
                      : _buildUnifiedDashboard(),
            ),
          ],
        ),
      ),
    );
  }
}

