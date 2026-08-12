import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/calendar/models/couple_event.dart';
import 'package:pawdo/features/calendar/services/couple_calendar_service.dart';

CoupleEvent event(String id, DateTime date) => CoupleEvent(
  id: id,
  title: id,
  description: '',
  date: date,
  category: CoupleEventCategory.special,
  emoji: '📅',
  reminderMinutes: null,
  createdBy: 'user-one',
  photoPath: null,
);

void main() {
  test('every calendar category has a user-facing label', () {
    for (final category in CoupleEventCategory.values) {
      final value = CoupleEvent(
        id: 'event',
        title: 'Evento',
        description: '',
        date: DateTime(2026),
        category: category,
        emoji: '📅',
        reminderMinutes: null,
        createdBy: 'user-one',
        photoPath: null,
      );
      expect(value.categoryLabel, isNotEmpty);
    }
  });

  test('occursOn compares the calendar day and ignores the time', () {
    final value = event('date', DateTime(2026, 8, 11, 23, 30));
    expect(value.occursOn(DateTime(2026, 8, 11, 1)), isTrue);
    expect(value.occursOn(DateTime(2026, 8, 12)), isFalse);
  });

  test('upcoming removes past events and orders the rest', () {
    final now = DateTime(2026, 8, 11, 12);
    final result = CoupleCalendarService.upcoming([
      event('later', now.add(const Duration(days: 2))),
      event('past', now.subtract(const Duration(seconds: 1))),
      event('next', now.add(const Duration(minutes: 5))),
    ], now);
    expect(result.map((value) => value.id), ['next', 'later']);
  });
}
