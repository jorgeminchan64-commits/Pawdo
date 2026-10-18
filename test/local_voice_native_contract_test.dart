import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local Pawdo voice path has no cloud or Firebase dependency', () {
    final source = File(
      'android/app/src/main/kotlin/com/pawdo/app/LocalVoiceController.kt',
    ).readAsStringSync();

    expect(source, contains('pawdo_voice_repeat_'));
    expect(source, contains('temporaryDeleted'));
    expect(source, contains('"uploaded" to false'));
    expect(source, contains('pendingPlaybackError'));
    expect(source, contains('voice-cancelled'));
    expect(source.toLowerCase(), isNot(contains('firebase')));
    expect(source.toLowerCase(), isNot(contains('http')));
  });

  test('activity cancels local audio when Pawdo leaves the foreground', () {
    final activity = File(
      'android/app/src/main/kotlin/com/pawdo/app/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('override fun onStop()'));
    expect(activity, contains('localVoiceController.cancel()'));
    expect(activity, contains('localVoiceController.dispose()'));
  });
}
