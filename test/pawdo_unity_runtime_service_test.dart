import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/three_d/services/pawdo_unity_runtime_service.dart';
import 'package:pawdo/features/three_d/models/pawdo_3d_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pawdo/unity_runtime');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'keeps the working screen when native runtime lacks the scene',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'capabilities') {
          return {
            'available': true,
            'bridgeSchemaVersion': 1,
            'supportedScenes': ['garden', 'interior'],
          };
        }
        return true;
      });
      expect(
        await const PawdoUnityRuntimeService().launch(Pawdo3DScene.pet),
        isFalse,
      );
      expect(calls, ['capabilities']);
    },
  );

  test(
    'launches only a scene advertised by a compatible native runtime',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'capabilities') {
          return {
            'available': true,
            'bridgeSchemaVersion': 1,
            'supportedScenes': ['garden', 'interior'],
          };
        }
        expect((call.arguments as Map)['scene'], 'garden');
        return true;
      });
      expect(
        await const PawdoUnityRuntimeService().launch(Pawdo3DScene.garden),
        isTrue,
      );
      expect(calls, ['capabilities', 'launch']);
    },
  );

  test('does not launch a runtime with unknown scene capabilities', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities') {
        return {'available': true, 'bridgeSchemaVersion': 1};
      }
      return true;
    });
    expect(
      await const PawdoUnityRuntimeService().launch(Pawdo3DScene.garden),
      isFalse,
    );
  });

  test(
    'voice level is clamped and sent through the versioned envelope',
    () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return true;
      });

      final sent = await const PawdoUnityRuntimeService().sendVoiceLevel(
        rms: 2.5,
        peak: -0.5,
        active: true,
      );

      expect(sent, isTrue);
      expect(captured.method, 'send');
      final arguments = captured.arguments as Map<Object?, Object?>;
      final envelope =
          jsonDecode(arguments['envelope']! as String) as Map<String, dynamic>;
      expect(envelope['schemaVersion'], 1);
      expect(envelope['type'], 'voice.level');
      expect(envelope['payload'], {'active': true, 'rms': 1.0, 'peak': 0.0});
    },
  );

  test('playback signal contains no audio or private content', () async {
    late Map<String, dynamic> envelope;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      envelope =
          jsonDecode(arguments['envelope']! as String) as Map<String, dynamic>;
      return true;
    });

    await const PawdoUnityRuntimeService().setVoicePlayback(active: true);

    expect(envelope['type'], 'voice.playback');
    expect(envelope['payload'], {'active': true, 'rms': 0.0, 'peak': 0.0});
  });

  test('lifecycle messages use the same bounded native transport', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });

    expect(await const PawdoUnityRuntimeService().pause(), isTrue);
    expect(await const PawdoUnityRuntimeService().resume(), isTrue);
    expect(await const PawdoUnityRuntimeService().unload(), isTrue);
    expect(methods, ['send', 'send', 'send']);
  });
}
