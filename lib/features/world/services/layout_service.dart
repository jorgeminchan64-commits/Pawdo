import 'package:cloud_functions/cloud_functions.dart';

class LayoutException implements Exception {
  const LayoutException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class LayoutService {
  LayoutService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<int> saveSharedLayout({
    required String coupleCode,
    required String area,
    required List<Map<String, dynamic>> layout,
    required int expectedRevision,
  }) async {
    final result = await _call('saveSharedLayout', {
      'coupleCode': coupleCode,
      'area': area,
      'layout': layout,
      'expectedRevision': expectedRevision,
    });
    return (result['revision'] as num?)?.toInt() ?? expectedRevision + 1;
  }

  Future<void> equipHouse({
    required String coupleCode,
    required String houseId,
  }) async {
    await _call('equipHouse', {'coupleCode': coupleCode, 'houseId': houseId});
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(functionName).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw LayoutException(error.code, _messageFor(error));
    } catch (_) {
      throw const LayoutException(
        'unavailable',
        'No se pudo guardar. Revisa tu conexión e intenta otra vez.',
      );
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'aborted':
        return 'Tu pareja guardó cambios antes. Recarga para no perderlos.';
      case 'permission-denied':
      case 'failed-precondition':
        return error.message ?? 'Este cambio ya no está permitido.';
      case 'invalid-argument':
        return error.message ?? 'La distribución contiene datos no válidos.';
      default:
        return error.message ??
            'No se pudo guardar. Revisa tu conexión e intenta otra vez.';
    }
  }
}
