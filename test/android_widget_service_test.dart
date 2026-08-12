import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/services/android_widget_service.dart';

void main() {
  test('widget data prioritizes the next event over pet fallback', () {
    const value = WidgetDashboardData(
      daysTogether: 465,
      duration: '1 año, 3 meses, 8 días juntos ❤️',
      nextEvent: '🍽️ Cena',
      petStatus: '🐾 Pawdo los espera',
    );
    expect(value.title, '465 días juntos ❤️');
    expect(value.activity, '🍽️ Cena');
  });

  test('widget data falls back to Pawdo when no event exists', () {
    const value = WidgetDashboardData(
      daysTogether: 1,
      duration: '1 día juntos ❤️',
      nextEvent: '',
      petStatus: '🐾 Pawdo los espera',
    );
    expect(value.title, '1 día juntos ❤️');
    expect(value.activity, '🐾 Pawdo los espera');
  });
}
