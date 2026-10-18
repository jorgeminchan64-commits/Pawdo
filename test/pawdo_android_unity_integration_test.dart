import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android links unityLibrary only when a reproducible export exists', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final appBuild = File('android/app/build.gradle.kts').readAsStringSync();

    expect(settings, contains('pawdoUnityLibrary'));
    expect(settings, contains('pawdoUnityEnabled'));
    expect(settings, contains('resolve("build.gradle").isFile'));
    expect(appBuild, contains('findProject(":unityLibrary")'));
    expect(appBuild, contains('minSdk = 26'));
  });

  test('native runtime keeps reflection-based legacy fallback', () {
    final activity = File(
      'android/app/src/main/kotlin/com/pawdo/app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('unityRuntimeAvailable()'));
    expect(activity, contains('Class.forName(unityPlayerActivity)'));
    expect(activity, contains('pawdo.bridge.initialization'));
    expect(activity, contains('ReceiveFromFlutter'));
  });

  test('Unity exporter removes the second launcher entry', () {
    final exporter = File(
      'unity/Pawdo3D/Assets/Pawdo/Editor/PawdoAndroidLibraryExporter.cs',
    ).readAsStringSync();

    expect(exporter, contains('NormalizeLibraryManifest'));
    expect(exporter, contains('activity.SetAttribute("exported"'));
    expect(exporter, contains('activity.RemoveChild(intentFilters[index])'));
  });

  test('Unity host reuses one runtime and returns to Flutter safely', () {
    final activity = File(
      'android/app/src/main/kotlin/com/pawdo/app/MainActivity.kt',
    ).readAsStringSync();
    final mainScreen = File(
      'lib/features/home/screens/main_screen.dart',
    ).readAsStringSync();
    final exporter = File(
      'unity/Pawdo3D/Assets/Pawdo/Editor/PawdoAndroidLibraryExporter.cs',
    ).readAsStringSync();

    expect(activity, contains('com.pawdo.app.PawdoUnityActivity'));
    expect(activity, contains('Intent.FLAG_ACTIVITY_REORDER_TO_FRONT'));
    expect(mainScreen, contains("ValueKey('pet-3d-\$petRuntimeVisit')"));
    expect(exporter, contains('KeyEvent.KEYCODE_BACK'));
    expect(exporter, contains('returnToFlutter'));
    expect(exporter, contains('pawdoActivity.SetAttribute("taskAffinity"'));
    expect(exporter, contains('UnityPlayer.UnitySendMessage'));
  });
}
