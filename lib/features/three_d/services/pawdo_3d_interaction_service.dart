import '../../economy/services/economy_service.dart';
import '../bridge/pawdo_bridge_envelope.dart';

typedef Pawdo3DActionExecutor =
    Future<Map<String, dynamic>> Function(
      String coupleCode,
      String actionId,
      String operationId,
    );

class Pawdo3DInteractionException implements Exception {
  const Pawdo3DInteractionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class Pawdo3DInteractionService {
  Pawdo3DInteractionService({
    EconomyService? economyService,
    Pawdo3DActionExecutor? executor,
  }) : _executor =
           executor ??
           ((coupleCode, actionId, operationId) =>
               (economyService ?? EconomyService()).performAction(
                 coupleCode: coupleCode,
                 actionId: actionId,
                 operationId: operationId,
               ));

  static const _targets = <String, ({String scene, String target})>{
    'world_water': (scene: 'garden', target: 'plant.primary'),
    'world_sit': (scene: 'garden', target: 'seat.primary'),
    'world_pet': (scene: 'garden', target: 'pet.pawdo'),
    'world_hug': (scene: 'garden', target: 'partner.avatar'),
    'interior_sleep': (scene: 'interior', target: 'bed.double'),
    'interior_sit': (scene: 'interior', target: 'sofa.primary'),
    'interior_eat': (scene: 'interior', target: 'table.dining'),
    'interior_movie': (scene: 'interior', target: 'tv.primary'),
    'interior_plant': (scene: 'interior', target: 'plant.interior'),
    'interior_pet': (scene: 'interior', target: 'pet.pawdo'),
    'interior_hug': (scene: 'interior', target: 'partner.avatar'),
  };

  static const _allowedPayloadKeys = {
    'scene',
    'actionId',
    'targetId',
    'completed',
  };

  final Pawdo3DActionExecutor _executor;

  Future<PawdoBridgeEnvelope> handle({
    required String rawEnvelope,
    required String coupleCode,
  }) async {
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(coupleCode)) {
      throw const Pawdo3DInteractionException(
        'invalid-couple-code',
        'La sesión 3D no tiene una pareja válida.',
      );
    }
    final request = PawdoBridgeEnvelope.decode(rawEnvelope);
    if (request.type != 'interaction.request') {
      throw const Pawdo3DInteractionException(
        'wrong-message-type',
        'El mensaje 3D no solicita una interacción.',
      );
    }
    if (request.payload.keys
        .toSet()
        .difference(_allowedPayloadKeys)
        .isNotEmpty) {
      throw const Pawdo3DInteractionException(
        'unexpected-interaction-fields',
        'La interacción contiene campos no autorizados.',
      );
    }
    if (request.payload['completed'] != true) {
      throw const Pawdo3DInteractionException(
        'interaction-incomplete',
        'La acción 3D todavía no se completó.',
      );
    }
    final actionId = request.payload['actionId'];
    final scene = request.payload['scene'];
    final targetId = request.payload['targetId'];
    final contract = actionId is String ? _targets[actionId] : null;
    if (contract == null ||
        scene != contract.scene ||
        targetId != contract.target) {
      throw const Pawdo3DInteractionException(
        'interaction-target-mismatch',
        'La acción no corresponde al objeto 3D alcanzado.',
      );
    }

    try {
      final canonical = await _executor(
        coupleCode,
        actionId,
        request.messageId,
      );
      return PawdoBridgeEnvelope.create(
        type: 'interaction.result',
        correlationId: request.messageId,
        payload: {
          'accepted': true,
          'operationId': request.messageId,
          'actionId': actionId,
          'canonical': _safeCanonicalResult(canonical),
        },
      );
    } on EconomyException catch (error) {
      return PawdoBridgeEnvelope.create(
        type: 'interaction.result',
        correlationId: request.messageId,
        payload: {
          'accepted': false,
          'operationId': request.messageId,
          'actionId': actionId,
          'errorCode': error.code,
          'errorMessage': error.message,
        },
      );
    }
  }

  Map<String, Object?> _safeCanonicalResult(Map<String, dynamic> source) {
    const keys = {
      'awarded',
      'alreadyClaimed',
      'idempotentReplay',
      'originallyAwarded',
      'coins',
      'love',
      'energy',
      'balanceAfter',
      'receiptId',
      'plantStage',
      'plantWaterings',
      'missionCompleted',
    };
    return {
      for (final key in keys)
        if (source.containsKey(key) &&
            (source[key] == null ||
                source[key] is bool ||
                source[key] is num ||
                source[key] is String))
          key: source[key],
    };
  }
}
