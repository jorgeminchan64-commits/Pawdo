import 'package:cloud_functions/cloud_functions.dart';

class EconomyException implements Exception {
  const EconomyException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class EconomyService {
  EconomyService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> performAction({
    required String coupleCode,
    required String actionId,
  }) => _call('performCoupleAction', {
    'coupleCode': coupleCode,
    'actionId': actionId,
  });

  Future<Map<String, dynamic>> purchaseItem({
    required String coupleCode,
    required String itemId,
  }) => _call('purchaseItem', {'coupleCode': coupleCode, 'itemId': itemId});

  Future<Map<String, dynamic>> claimDailyReward(String coupleCode) =>
      _call('claimDailyReward', {'coupleCode': coupleCode});

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(functionName).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw EconomyException(error.code, _messageFor(error));
    } catch (_) {
      throw const EconomyException(
        'unavailable',
        'No se pudo completar la operación. Revisa tu conexión.',
      );
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'failed-precondition':
        return error.message ?? 'No hay monedas suficientes.';
      case 'permission-denied':
        return 'Ya no tienes acceso a la economía de esta pareja.';
      case 'resource-exhausted':
        return 'Espera un momento antes de intentarlo otra vez.';
      case 'unavailable':
        return 'Sin conexión. La compra no fue confirmada.';
      default:
        return error.message ?? 'No se pudo completar la operación.';
    }
  }
}
