import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/wellness_models.dart';

class WellnessException implements Exception {
  const WellnessException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WellnessService {
  WellnessService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const WellnessException('Inicia sesión para continuar.');
    }
    return uid;
  }

  Stream<WellnessSettings> watchSettings() => _firestore
      .collection('users')
      .doc(_uid)
      .collection('wellness')
      .doc('settings')
      .snapshots()
      .map((snapshot) => WellnessSettings.fromMap(snapshot.data()));

  Stream<List<WellnessEntry>> watchEntries() => _firestore
      .collection('users')
      .doc(_uid)
      .collection('wellnessEntries')
      .orderBy('dateKey', descending: true)
      .limit(370)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(WellnessEntry.fromDocument).toList(),
      );

  Future<void> saveSettings({
    required int cycleLength,
    required int periodLength,
    required bool regularCycle,
    required bool remindersEnabled,
    required bool sharingEnabled,
    required Set<String> sharedFields,
  }) => _call('saveWellnessSettings', {
    'cycleLength': cycleLength,
    'periodLength': periodLength,
    'regularCycle': regularCycle,
    'remindersEnabled': remindersEnabled,
    'sharingEnabled': sharingEnabled,
    'sharedFields': sharedFields.toList()..sort(),
  });

  Future<void> saveEntry({
    required DateTime date,
    required String mood,
    required String flow,
    required Set<String> symptoms,
    required String notes,
    required bool periodStarted,
    required bool periodEnded,
  }) => _call('saveWellnessEntry', {
    'dateKey': _dateKey(date),
    'mood': mood,
    'flow': flow,
    'symptoms': symptoms.toList()..sort(),
    'notes': notes,
    'periodStarted': periodStarted,
    'periodEnded': periodEnded,
  });

  Future<void> deleteEntry(String dateKey) =>
      _call('deleteWellnessEntry', {'dateKey': dateKey});

  Future<void> deleteAllData() =>
      _call('deleteWellnessData', {'confirm': true});

  Future<Stream<DocumentSnapshot<Map<String, dynamic>>>?>
  partnerSummary() async {
    final profile = await _firestore.collection('users').doc(_uid).get();
    final code = profile.data()?['coupleCode']?.toString() ?? '';
    if (code.isEmpty) return null;
    final couple = await _firestore.collection('couples').doc(code).get();
    final data = couple.data() ?? const <String, dynamic>{};
    final partnerUid = data['user1'] == _uid
        ? data['user2']?.toString() ?? ''
        : data['user1']?.toString() ?? '';
    if (partnerUid.isEmpty) return null;
    return _firestore
        .collection('couples')
        .doc(code)
        .collection('wellnessShared')
        .doc(partnerUid)
        .snapshots();
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw WellnessException(error.message ?? 'No se pudo guardar el cambio.');
    } on FirebaseException catch (error) {
      throw WellnessException(error.message ?? 'Error de conexión con Pawdo.');
    } catch (_) {
      throw const WellnessException('No se pudo completar la operación.');
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
