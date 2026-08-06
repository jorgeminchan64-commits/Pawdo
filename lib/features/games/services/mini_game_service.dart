import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MiniGameException implements Exception {
  const MiniGameException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniGameService {
  MiniGameService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String get currentUid => _auth.currentUser?.uid ?? '';

  Future<String> requireCoupleCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const MiniGameException('Inicia sesión para jugar.');
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final coupleCode = userSnapshot.data()?['coupleCode']?.toString() ?? '';
    if (coupleCode.isEmpty) {
      throw const MiniGameException(
        'Conecta tu cuenta con tu pareja para jugar.',
      );
    }
    return coupleCode;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(
    String coupleCode,
    String gameId,
  ) {
    return _firestore
        .collection('couples')
        .doc(coupleCode)
        .collection('games')
        .doc(gameId)
        .snapshots();
  }

  Future<void> openGame(String coupleCode, String gameId) async {
    await _call('openMiniGame', <String, dynamic>{
      'coupleCode': coupleCode,
      'gameId': gameId,
    });
  }

  Future<Map<String, dynamic>> play({
    required String coupleCode,
    required String gameId,
    required String action,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return _call('playMiniGame', <String, dynamic>{
      'coupleCode': coupleCode,
      'gameId': gameId,
      'action': action,
      'payload': payload,
    });
  }

  Future<Map<String, dynamic>> _call(
    String callable,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(callable).call(data);
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (error) {
      throw MiniGameException(
        error.message ?? 'No se pudo completar la jugada.',
      );
    } on FirebaseException catch (error) {
      throw MiniGameException(error.message ?? 'Error de conexión con Pawdo.');
    } catch (_) {
      throw const MiniGameException(
        'No se pudo conectar con el juego. Inténtalo otra vez.',
      );
    }
  }
}
