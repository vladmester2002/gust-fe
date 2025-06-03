import 'package:flutter_test/flutter_test.dart';
import 'package:gust_fe/analytics_page.dart';

void main() {
  group('getCleanMaxY', () {
    test('returns at least 10', () {
      expect(getCleanMaxY(2), 10);
      expect(getCleanMaxY(10), 10);
    });

    test('rounds up to next base', () {
      expect(getCleanMaxY(57), 60);
      expect(getCleanMaxY(101), 200);
    });
  });

  group('getYAxisStep', () {
    test('returns correct step', () {
      expect(getYAxisStep(8), 2);
      expect(getYAxisStep(50), 10);
      expect(getYAxisStep(100), 20);
      expect(getYAxisStep(200), 40);
    });
  });
}