import 'package:cloud_firestore/cloud_firestore.dart';

enum PetAction { feed, play, sleep }

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _ref(String coupleCode) =>
      _db.collection('couples').doc(coupleCode).collection('state').doc('pet');
  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String coupleCode) =>
      _ref(coupleCode).snapshots();

  Future<void> performAction(String coupleCode, PetAction action) async {
    final ref = _ref(coupleCode);
    await _db.runTransaction((transaction) async {
      final current =
          (await transaction.get(ref)).data() ?? <String, dynamic>{};
      int value(String key, int fallback) =>
          (current[key] as num?)?.toInt() ?? fallback;
      var hunger = value('hunger', 70);
      var happiness = value('happiness', 80);
      var energy = value('energy', 65);
      switch (action) {
        case PetAction.feed:
          hunger += 20;
          happiness += 4;
          break;
        case PetAction.play:
          happiness += 15;
          energy -= 12;
          hunger -= 8;
          break;
        case PetAction.sleep:
          energy += 25;
          hunger -= 6;
          break;
      }
      int clamp(int number) => number.clamp(0, 100);
      transaction.set(ref, {
        'name': current['name'] ?? 'Pawdo',
        'hunger': clamp(hunger),
        'happiness': clamp(happiness),
        'energy': clamp(energy),
        'lastAction': action.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
