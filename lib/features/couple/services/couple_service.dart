import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoupleException implements Exception {
  const CoupleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CoupleService {
  CoupleService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<String> createCoupleCode() async {
    _requireUser();
    final data = await _call('createCoupleCode');
    final coupleCode = data['coupleCode']?.toString() ?? '';
    if (coupleCode.length != 6) {
      throw const CoupleException('Firebase no devolvió un código válido.');
    }
    return coupleCode;
  }

  Future<void> joinCouple(String code) async {
    _requireUser();
    final cleanCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(cleanCode)) {
      throw const CoupleException('El código debe tener 6 letras o números.');
    }
    await _call('joinCouple', <String, dynamic>{'coupleCode': cleanCode});
  }

  Future<void> cancelCoupleInvitation() async {
    _requireUser();
    await _call('cancelCoupleInvitation');
  }

  Future<void> unlinkCouple() async {
    _requireUser();
    await _call('unlinkCouple', <String, dynamic>{'confirm': true});
  }

  Future<Map<String, dynamic>> repairCoupleMembership() async {
    _requireUser();
    return _call('repairCoupleMembership');
  }

  Future<void> refreshCoupleProfiles() async {
    _requireUser();
    await _call('refreshCoupleProfiles');
  }

  Future<void> setPresence(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _call('setCouplePresence', <String, dynamic>{'online': online});
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    } on CoupleException {
      // Presence is best-effort and must never block authentication.
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CoupleException('Inicia sesión para continuar.');
    }
    return user;
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic> data = const <String, dynamic>{},
  ]) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (error) {
      final serverMessage = error.message?.trim();
      if (error.code == 'not-found' &&
          (serverMessage == null ||
              serverMessage.isEmpty ||
              serverMessage.toUpperCase() == 'NOT_FOUND')) {
        throw const CoupleException(
          'Esta función todavía no está publicada en Firebase. '
          'Actualiza las Functions e inténtalo nuevamente.',
        );
      }
      if (serverMessage != null && serverMessage.isNotEmpty) {
        throw CoupleException(serverMessage);
      }
      if (error.code == 'unavailable' || error.code == 'aborted') {
        throw const CoupleException('Error temporal. Inténtalo nuevamente.');
      }
      throw const CoupleException('No se pudo conectar la pareja.');
    } on FirebaseException catch (_) {
      throw const CoupleException(
        'No se pudo conectar con Firebase. Revisa tu internet.',
      );
    } catch (_) {
      throw const CoupleException(
        'Ocurrió un error inesperado. Inténtalo nuevamente.',
      );
    }
  }
}
