import 'package:cloud_functions/cloud_functions.dart';

class RelationshipException implements Exception {
  const RelationshipException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RelationshipService {
  RelationshipService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> setStartDate(String coupleCode, DateTime date) async {
    try {
      await _functions.httpsCallable('setRelationshipStartDate').call({
        'coupleCode': coupleCode,
        'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw RelationshipException(
        error.message ?? 'No se pudo actualizar la fecha de relación.',
      );
    }
  }
}
