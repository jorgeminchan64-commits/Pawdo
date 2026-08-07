import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/profile/models/profile_data.dart';

void main() {
  group('ProfileData', () {
    test('keeps legacy name as visible-name fallback', () {
      final profile = ProfileData.fromMap(<String, dynamic>{'name': 'Jorge'});

      expect(profile.displayName, 'Jorge');
      expect(profile.greetingName, 'Jorge');
      expect(profile.theme, ProfileTheme.rose);
    });

    test('falls back safely from unknown themes', () {
      final profile = ProfileData.fromMap(<String, dynamic>{
        'name': 'Jorge',
        'displayName': 'J',
        'profileTheme': 'removed-theme',
      });

      expect(profile.greetingName, 'J');
      expect(profile.theme, ProfileTheme.rose);
    });

    test('counts calendar days without returning negatives', () {
      final profile = ProfileData.fromMap(<String, dynamic>{
        'relationshipStartDate': DateTime(2026, 8, 1, 23, 30),
      });
      final future = ProfileData.fromMap(<String, dynamic>{
        'relationshipStartDate': DateTime(2027, 1, 1),
      });

      expect(profile.daysTogether(DateTime(2026, 8, 7, 1)), 6);
      expect(future.daysTogether(DateTime(2026, 8, 7)), 0);
    });
  });
}
