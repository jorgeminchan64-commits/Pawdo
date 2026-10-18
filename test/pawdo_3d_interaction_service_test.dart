import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/economy/services/economy_service.dart';
import 'package:pawdo/features/three_d/bridge/pawdo_bridge_envelope.dart';
import 'package:pawdo/features/three_d/services/pawdo_3d_interaction_service.dart';

void main() {
  PawdoBridgeEnvelope request({
    String scene = 'garden',
    String actionId = 'world_water',
    String targetId = 'plant.primary',
    bool completed = true,
    Map<String, dynamic> extra = const {},
  }) => PawdoBridgeEnvelope.create(
    type: 'interaction.request',
    payload: {
      'scene': scene,
      'actionId': actionId,
      'targetId': targetId,
      'completed': completed,
      ...extra,
    },
  );

  test('uses the bridge message id as the server idempotency key', () async {
    String? receivedCode;
    String? receivedAction;
    String? receivedOperation;
    final service = Pawdo3DInteractionService(
      executor: (coupleCode, actionId, operationId) async {
        receivedCode = coupleCode;
        receivedAction = actionId;
        receivedOperation = operationId;
        return {
          'awarded': true,
          'coins': 25,
          'balanceAfter': 40,
          'serverOnlyUnexpectedField': 'discard me',
        };
      },
    );
    final incoming = request();

    final result = await service.handle(
      rawEnvelope: incoming.encode(),
      coupleCode: 'ABC123',
    );

    expect(receivedCode, 'ABC123');
    expect(receivedAction, 'world_water');
    expect(receivedOperation, incoming.messageId);
    expect(result.type, 'interaction.result');
    expect(result.correlationId, incoming.messageId);
    expect(result.payload['accepted'], isTrue);
    final canonical = result.payload['canonical'] as Map<String, dynamic>;
    expect(canonical['coins'], 25);
    expect(canonical, isNot(contains('serverOnlyUnexpectedField')));
  });

  test('never calls economy for an incomplete animation', () async {
    var calls = 0;
    final service = Pawdo3DInteractionService(
      executor: (_, _, _) async {
        calls++;
        return {};
      },
    );

    await expectLater(
      service.handle(
        rawEnvelope: request(completed: false).encode(),
        coupleCode: 'ABC123',
      ),
      throwsA(
        isA<Pawdo3DInteractionException>().having(
          (error) => error.code,
          'code',
          'interaction-incomplete',
        ),
      ),
    );
    expect(calls, 0);
  });

  test('rejects a reward forged inside a Unity payload', () async {
    final service = Pawdo3DInteractionService(executor: (_, _, _) async => {});

    await expectLater(
      service.handle(
        rawEnvelope: request(extra: {'coins': 999999}).encode(),
        coupleCode: 'ABC123',
      ),
      throwsA(
        isA<Pawdo3DInteractionException>().having(
          (error) => error.code,
          'code',
          'unexpected-interaction-fields',
        ),
      ),
    );
  });

  test('rejects an action that does not match the reached 3D target', () async {
    final service = Pawdo3DInteractionService(executor: (_, _, _) async => {});

    await expectLater(
      service.handle(
        rawEnvelope: request(targetId: 'grass.empty').encode(),
        coupleCode: 'ABC123',
      ),
      throwsA(
        isA<Pawdo3DInteractionException>().having(
          (error) => error.code,
          'code',
          'interaction-target-mismatch',
        ),
      ),
    );
  });

  test(
    'returns a correlated rejection when the server refuses an action',
    () async {
      final service = Pawdo3DInteractionService(
        executor: (_, _, _) async =>
            throw const EconomyException('unavailable', 'Sin conexión.'),
      );
      final incoming = request();

      final result = await service.handle(
        rawEnvelope: incoming.encode(),
        coupleCode: 'ABC123',
      );

      expect(result.correlationId, incoming.messageId);
      expect(result.payload['accepted'], isFalse);
      expect(result.payload['errorCode'], 'unavailable');
    },
  );
}
