import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hardware permissions stay optional and background location is absent',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
      expect(manifest, contains('android.hardware.camera'));
      expect(manifest, contains('android.hardware.microphone'));
      expect(
        RegExp(
          r'android\.hardware\.(camera|microphone)"\s+android:required="false"',
        ).allMatches(manifest),
        hasLength(2),
      );
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    },
  );

  test('release does not add unused Firebase Analytics directly', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('firebase-analytics')));
  });
}
