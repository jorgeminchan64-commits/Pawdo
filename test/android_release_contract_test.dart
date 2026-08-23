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

  test('Play release targets API 36 and inherits the Flutter version', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));
    expect(gradle, isNot(contains('versionName = "1.0"')));
  });

  test('adaptive icon uses a transparent foreground and monochrome layer', () {
    final icon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_v2.xml',
    ).readAsStringSync();

    expect(icon, contains('@mipmap/ic_launcher_foreground_v2'));
    expect(icon, contains('<monochrome'));
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/mipmap-$density/'
          'ic_launcher_foreground_v2.png',
        ).existsSync(),
        isTrue,
        reason: 'Missing adaptive foreground for $density',
      );
      expect(
        File(
          'android/app/src/main/res/mipmap-$density/ic_launcher_v2.png',
        ).existsSync(),
        isTrue,
        reason: 'Missing legacy launcher icon for $density',
      );
    }
  });

  test('release signing reads only ignored local credentials', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ignores = File('.gitignore').readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('signingConfigs'));
    expect(gradle, isNot(contains('storePassword = "')));
    expect(ignores, contains('/android/key.properties'));
    expect(ignores, contains('**/*.jks'));
  });

  test('offline release builds can skip only Crashlytics map upload', () {
    final build = File('android/app/build.gradle.kts').readAsStringSync();

    expect(build, contains('pawdoSkipCrashlyticsMappingUpload'));
    expect(build, contains('mappingFileUploadEnabled'));
    expect(build, contains('!skipCrashlyticsMappingUpload'));
  });
}
