import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/home/models/home_dashboard_summary.dart';

void main() {
  group('greetingForHour', () {
    test('uses morning, afternoon and night ranges', () {
      expect(greetingForHour(5), 'Buenos días');
      expect(greetingForHour(11), 'Buenos días');
      expect(greetingForHour(12), 'Buenas tardes');
      expect(greetingForHour(18), 'Buenas tardes');
      expect(greetingForHour(19), 'Buenas noches');
      expect(greetingForHour(4), 'Buenas noches');
    });
  });

  test('formats the dashboard clock with leading zeroes', () {
    expect(formatDashboardClock(DateTime(2026, 8, 7, 7, 5)), '07:05');
  });

  group('relationshipSummary', () {
    test('formats calendar years, months and days', () {
      final summary = relationshipSummary(
        DateTime(2025, 5, 10),
        DateTime(2026, 8, 18),
      );

      expect(summary.durationLabel, '1 año, 3 meses, 8 días juntos ❤️');
      expect(summary.nextMomentLabel, 'Próximo aniversario en 265 días');
      expect(summary.totalDays, 465);
      expect(summary.nextAnniversary, DateTime(2027, 5, 10));
    });

    test('announces the anniversary on its date', () {
      final summary = relationshipSummary(
        DateTime(2024, 2, 29),
        DateTime(2025, 2, 28),
      );

      expect(summary.durationLabel, '1 año juntos ❤️');
      expect(summary.nextMomentLabel, '¡Su aniversario es hoy! ❤️');
      expect(summary.nextAnniversary, DateTime(2025, 2, 28));
    });

    test('provides a safe prompt when the date is missing', () {
      final summary = relationshipSummary(null, DateTime(2026, 8, 7));

      expect(summary.durationLabel, 'Su historia empieza aquí');
      expect(summary.nextMomentLabel, contains('Perfil'));
      expect(summary.totalDays, 0);
      expect(summary.nextAnniversary, isNull);
    });
  });
}
