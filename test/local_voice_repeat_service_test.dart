import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/pet/services/local_voice_repeat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pawdo/local_voice');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'requests microphone just in time and starts only after permission',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'capabilities' => <String, Object>{
            'available': true,
            'permission': false,
            'localOnly': true,
          },
          'requestPermission' => true,
          'start' => <String, Object>{'accepted': true, 'localOnly': true},
          _ => null,
        };
      });

      await const LocalVoiceRepeatService().requestPermissionAndStart();

      expect(calls, ['capabilities', 'requestPermission', 'start']);
    },
  );

  test('never starts recording when microphone permission is denied', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'capabilities' => <String, Object>{
          'available': true,
          'permission': false,
        },
        'requestPermission' => false,
        _ => null,
      };
    });

    await expectLater(
      const LocalVoiceRepeatService().requestPermissionAndStart(),
      throwsA(
        isA<LocalVoiceRepeatException>().having(
          (error) => error.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    expect(calls, ['capabilities', 'requestPermission']);
  });

  test('clamps native audio levels to the safe display range', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'level');
      return <String, Object>{
        'recording': true,
        'playing': false,
        'rms': 2.4,
        'peak': -0.2,
        'voiceDetected': true,
      };
    });

    final level = await const LocalVoiceRepeatService().level();

    expect(level.rms, 1.0);
    expect(level.peak, 0.0);
    expect(level.recording, isTrue);
    expect(level.voiceDetected, isTrue);
  });

  test(
    'accepts playback only when local deletion and no upload are proven',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'stopAndPlay');
        return <String, Object>{
          'durationMs': 1250,
          'temporaryDeleted': true,
          'uploaded': false,
        };
      });

      final result = await const LocalVoiceRepeatService().stopAndPlay();

      expect(result.duration, const Duration(milliseconds: 1250));
      expect(result.temporaryDeleted, isTrue);
      expect(result.uploaded, isFalse);
    },
  );

  test(
    'rejects any native result that violates the privacy contract',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String, Object>{
          'durationMs': 900,
          'temporaryDeleted': true,
          'uploaded': true,
        };
      });

      await expectLater(
        const LocalVoiceRepeatService().stopAndPlay(),
        throwsA(
          isA<LocalVoiceRepeatException>().having(
            (error) => error.code,
            'code',
            'voice-privacy-contract',
          ),
        ),
      );
    },
  );
}
