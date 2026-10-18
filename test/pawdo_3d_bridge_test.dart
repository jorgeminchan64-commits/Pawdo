import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/three_d/bridge/pawdo_bridge_envelope.dart';
import 'package:pawdo/features/three_d/models/pawdo_3d_scene.dart';

void main() {
  const fixtures = 'unity/Pawdo3D/Assets/StreamingAssets/PawdoBridgeFixtures';

  group('Pawdo bridge v1', () {
    test('Dart accepts the same initialization fixture as Unity', () {
      final raw = File(
        '$fixtures/runtime_initialize.valid.json',
      ).readAsStringSync();
      final envelope = PawdoBridgeEnvelope.decode(raw);
      expect(envelope.schemaVersion, 1);
      expect(envelope.type, 'runtime.initialize');
      expect(envelope.payload['locale'], 'es-PE');
    });

    test('Dart and Unity fixtures reject unsupported schema', () {
      final raw = File(
        '$fixtures/unsupported_schema.invalid.json',
      ).readAsStringSync();
      expect(
        () => PawdoBridgeEnvelope.decode(raw),
        throwsA(
          isA<PawdoBridgeFormatException>().having(
            (error) => error.code,
            'code',
            'unsupported-schema-version',
          ),
        ),
      );
    });

    test('Dart and Unity fixtures reject unknown type and missing payload', () {
      for (final entry in const {
        'unknown_type.invalid.json': 'unknown-message-type',
        'missing_payload.invalid.json': 'invalid-envelope-fields',
      }.entries) {
        final raw = File('$fixtures/${entry.key}').readAsStringSync();
        expect(
          () => PawdoBridgeEnvelope.decode(raw),
          throwsA(
            isA<PawdoBridgeFormatException>().having(
              (error) => error.code,
              'code',
              entry.value,
            ),
          ),
        );
      }
    });

    test('writer creates a strict, round-trippable envelope', () {
      final created = PawdoBridgeEnvelope.create(
        type: 'scene.load',
        payload: const {'scene': 'garden'},
        sentAt: DateTime.utc(2026, 8, 23),
      );
      final decoded = PawdoBridgeEnvelope.decode(created.encode());
      expect(decoded.messageId, created.messageId);
      expect(decoded.payload, {'scene': 'garden'});
    });
  });

  group('Pawdo 3D feature policy', () {
    test('master flag disabled always keeps the legacy fallback', () {
      const policy = Pawdo3DFeaturePolicy(
        masterEnabled: false,
        androidRuntime: true,
        enabledScenes: {Pawdo3DScene.garden},
      );
      expect(policy.canLaunch(Pawdo3DScene.garden), isFalse);
    });

    test('requires Android and the individual scene flag', () {
      const androidPolicy = Pawdo3DFeaturePolicy(
        masterEnabled: true,
        androidRuntime: true,
        enabledScenes: {Pawdo3DScene.garden},
      );
      const nonAndroidPolicy = Pawdo3DFeaturePolicy(
        masterEnabled: true,
        androidRuntime: false,
        enabledScenes: {Pawdo3DScene.garden},
      );
      expect(androidPolicy.canLaunch(Pawdo3DScene.garden), isTrue);
      expect(androidPolicy.canLaunch(Pawdo3DScene.interior), isFalse);
      expect(nonAndroidPolicy.canLaunch(Pawdo3DScene.garden), isFalse);
    });
  });
}
