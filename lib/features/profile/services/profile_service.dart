import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../media/services/shared_media_service.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SharedMediaException(
        SharedMediaError.unauthenticated,
        'Debes iniciar sesión para guardar tu foto de perfil.',
      );
    }

    final bytes = await SharedMediaService.compressFileToLimit(imageFile.path);
    final reference = _storage.ref().child('profile_photos/${user.uid}.jpg');
    await reference.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return reference.fullPath;
  }

  Future<void> saveProfile({
    required String name,
    required DateTime birthday,
    required DateTime relationshipStartDate,
    String? photoStoragePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no logueado');

    final profile = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'name': name.trim(),
      'birthday': Timestamp.fromDate(birthday),
      'relationshipStartDate': Timestamp.fromDate(relationshipStartDate),
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (photoStoragePath != null) {
      profile['photoStoragePath'] = photoStoragePath;
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .set(profile, SetOptions(merge: true));
  }
}
