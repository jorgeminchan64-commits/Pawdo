import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum PetAction { pet, feed, play, sleep, wake, bathe, toilet }

class PetException implements Exception {
  const PetException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class PetService {
  PetService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _ref(String coupleCode) =>
      _db.collection('couples').doc(coupleCode).collection('state').doc('pet');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String coupleCode) =>
      _ref(coupleCode).snapshots();

  Future<Map<String, dynamic>> performAction(
    String coupleCode,
    PetAction action,
  ) async {
    try {
      final result = await _functions.httpsCallable('performPetAction').call({
        'coupleCode': coupleCode,
        'action': action.name,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw PetException(error.code, _messageFor(error));
    } catch (_) {
      throw const PetException(
        'unavailable',
        'No se pudo cuidar a Pawdo. Revisa tu conexión.',
      );
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    return switch (error.code) {
      'failed-precondition' =>
        error.message ?? 'Pawdo no puede hacer eso ahora.',
      'resource-exhausted' => 'Dale un momento a Pawdo antes de otra acción.',
      'permission-denied' => 'Ya no tienes acceso a esta mascota compartida.',
      'unavailable' => 'Sin conexión. La acción no fue confirmada.',
      _ => error.message ?? 'No se pudo completar la acción.',
    };
  }
}
