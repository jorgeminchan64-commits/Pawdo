import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../couple/services/couple_service.dart';
import '../../media/services/shared_media_service.dart';
import '../models/profile_data.dart';

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ProfileRepository {
  Future<String> uploadProfilePhoto(File imageFile);

  Future<void> updateProfile({
    required String name,
    required String displayName,
    required DateTime birthday,
    required DateTime relationshipStartDate,
    required ProfileTheme theme,
    String? photoStoragePath,
  });
}

class ProfileService implements ProfileRepository {
  ProfileService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    CoupleService? coupleService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _coupleService = coupleService ?? CoupleService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final CoupleService _coupleService;

  @override
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
    String? displayName,
    ProfileTheme theme = ProfileTheme.rose,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no logueado');

    final profile = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'name': name.trim(),
      'displayName': (displayName ?? name).trim(),
      'birthday': Timestamp.fromDate(birthday),
      'relationshipStartDate': Timestamp.fromDate(relationshipStartDate),
      'profileTheme': theme.name,
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

  @override
  Future<void> updateProfile({
    required String name,
    required String displayName,
    required DateTime birthday,
    required DateTime relationshipStartDate,
    required ProfileTheme theme,
    String? photoStoragePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ProfileException('Inicia sesión para editar tu perfil.');
    }
    final cleanName = name.trim();
    final cleanDisplayName = displayName.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const ProfileException(
        'El nombre debe tener entre 1 y 80 caracteres.',
      );
    }
    if (cleanDisplayName.isEmpty || cleanDisplayName.length > 80) {
      throw const ProfileException(
        'El nombre visible debe tener entre 1 y 80 caracteres.',
      );
    }
    final today = DateTime.now();
    final oldest = DateTime(1900);
    if (birthday.isBefore(oldest) || birthday.isAfter(today)) {
      throw const ProfileException('Selecciona un cumpleaños válido.');
    }
    if (relationshipStartDate.isBefore(oldest) ||
        relationshipStartDate.isAfter(today)) {
      throw const ProfileException('Selecciona una fecha de relación válida.');
    }

    final changes = <String, dynamic>{
      'name': cleanName,
      'displayName': cleanDisplayName,
      'birthday': Timestamp.fromDate(birthday),
      'relationshipStartDate': Timestamp.fromDate(relationshipStartDate),
      'profileTheme': theme.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoStoragePath != null) {
      changes['photoStoragePath'] = photoStoragePath;
    }

    try {
      await _db.collection('users').doc(user.uid).update(changes);
    } on FirebaseException {
      throw const ProfileException(
        'No se pudo guardar el perfil. Revisa tu conexión e inténtalo otra vez.',
      );
    }

    try {
      await _coupleService.refreshCoupleProfiles();
    } catch (_) {
      // El perfil personal ya quedó guardado. El dashboard vuelve a solicitar
      // el resumen compartido al reconstruirse o recuperar conectividad.
    }
  }
}
