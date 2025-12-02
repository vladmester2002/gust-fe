import '../data/models/local_sugar_log.dart';
import '../analytics_page.dart'; // For AnalyticsResponse class

class LocalAnalyticsService {
  
  /// Compute daily sugar intake trend for a specific month
  static List<AnalyticsResponse> computeDailyTrend(List<LocalSugarLog> logs, int month, int year) {
    // Filter logs for the specific month and year
    final monthlyLogs = logs.where((log) => 
      log.date.month == month && log.date.year == year
    ).toList();

    // Group by day
    final Map<int, double> dailyTotals = {};
    for (final log in monthlyLogs) {
      final day = log.date.day;
      dailyTotals[day] = (dailyTotals[day] ?? 0) + log.sugarGrams;
    }

    // Convert to AnalyticsResponse list
    // We want to return data for days that have logs
    return dailyTotals.entries.map((entry) {
      final date = DateTime(year, month, entry.key);
      return AnalyticsResponse(
        label: date.toIso8601String().substring(0, 10), // YYYY-MM-DD
        value: entry.value,
      );
    }).toList();
  }

  /// Compute emotion summary for a specific month
  static List<AnalyticsResponse> computeEmotionSummary(List<LocalSugarLog> logs, int month, int year) {
    // Filter logs for the specific month and year
    final monthlyLogs = logs.where((log) => 
      log.date.month == month && log.date.year == year
    ).toList();

    // Group by emotion
    final Map<String, double> emotionTotals = {};
    final Map<String, int> emotionCounts = {};

    for (final log in monthlyLogs) {
      final emotion = log.emotion;
      emotionTotals[emotion] = (emotionTotals[emotion] ?? 0) + log.sugarGrams;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }

    // Convert to AnalyticsResponse list
    return emotionTotals.entries.map((entry) {
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
  }

  /// Compute time of day pattern for a specific date range (or single date)
  /// Note: The backend endpoint takes a single date, but the frontend logic 
  /// for `_fetchTimeDataForRange` iterates over a range. 
  /// Here we'll support computing for a list of logs that are already filtered by date range if needed,
  /// or we can filter inside.
  /// 
  /// To match `_fetchTimeDataForRange` logic in AnalyticsPage:
  /// It aggregates data over the requested range.
  static List<AnalyticsResponse> computeTimeOfDayPattern(List<LocalSugarLog> logs) {
    final Map<String, double> timeTotals = {};
    final Map<String, Set<String>> daysWithDataPerSlot = {}; // Track unique days per slot

    for (final log in logs) {
      final slot = _slotForHour(log.hour);
      timeTotals[slot] = (timeTotals[slot] ?? 0) + log.sugarGrams;
      
      daysWithDataPerSlot.putIfAbsent(slot, () => <String>{});
      daysWithDataPerSlot[slot]!.add(log.date.toIso8601String().substring(0, 10));
    }

    return timeTotals.entries.map((entry) {
      final slot = entry.key;
      final totalSugar = entry.value;
      final daysCount = daysWithDataPerSlot[slot]?.length ?? 1;
      final average = totalSugar / daysCount;

      return AnalyticsResponse(
        label: slot,
        value: totalSugar,
        detail: 'Avg: ${average.toStringAsFixed(1)}g per day | $daysCount days',
      );
    }).toList();
  }

  /// Compute monthly total (for the "Monthly Total" tab)
  static List<AnalyticsResponse> computeMonthlyTotal(List<LocalSugarLog> logs) {
    // Group by Year-Month
    final Map<String, double> monthlyTotals = {};

    for (final log in logs) {
      // Format: YYYY-MM
      final key = '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + log.sugarGrams;
    }

    return monthlyTotals.entries.map((entry) {
      return AnalyticsResponse(
        label: entry.key,
        value: entry.value,
      );
    }).toList();
  }

  static String _slotForHour(int hour) {
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 22) return 'Evening';
    return 'Night';
  }
}
