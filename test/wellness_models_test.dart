import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/wellness/models/wellness_models.dart';

WellnessSettings settings({required bool regular}) => WellnessSettings(
  enabled: true,
  cycleLength: 28,
  periodLength: 5,
  regularCycle: regular,
  remindersEnabled: false,
  sharingEnabled: false,
  sharedFields: const {},
);

void main() {
  test('regular cycles expose one orientative date', () {
    final insight = CycleInsights.fromStarts(
      [DateTime(2026, 6, 1), DateTime(2026, 6, 29), DateTime(2026, 7, 27)],
      settings(regular: true),
      now: DateTime(2026, 8, 1),
    );
    expect(insight.estimatedCycleLength, 28);
    expect(insight.nextPeriodEstimate, DateTime(2026, 8, 24));
    expect(insight.estimateRangeStart, isNull);
    expect(insight.estimateRangeEnd, isNull);
  });

  test('irregular cycles expose an observed approximate range', () {
    final insight = CycleInsights.fromStarts(
      [DateTime(2026, 5, 1), DateTime(2026, 5, 26), DateTime(2026, 6, 28)],
      settings(regular: false),
      now: DateTime(2026, 7, 1),
    );
    expect(insight.estimatedCycleLength, 29);
    expect(insight.estimateRangeStart, DateTime(2026, 7, 23));
    expect(insight.estimateRangeEnd, DateTime(2026, 7, 31));
  });

  test('wellness stays private and regular by safe default', () {
    final value = WellnessSettings.fromMap(null);
    expect(value.enabled, isFalse);
    expect(value.regularCycle, isTrue);
    expect(value.sharingEnabled, isFalse);
    expect(value.sharedFields, isEmpty);
  });
}
