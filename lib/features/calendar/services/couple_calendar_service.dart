import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../models/couple_event.dart';

class CalendarException implements Exception {
  const CalendarException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CoupleCalendarService {
  CoupleCalendarService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? picker,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _picker = picker ?? ImagePicker();

  static const maxPhotoBytes = 750 * 1024;
  static const reminderOptions = <int?>[null, 0, 30, 60, 1440, 10080];

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String coupleCode) => _db
      .collection('couples')
      .doc(coupleCode)
      .collection('calendarEvents')
      .orderBy('date')
      .limit(300)
      .snapshots();

  Future<void> create({
    required String coupleCode,
    required String title,
    required String description,
    required DateTime date,
    required CoupleEventCategory category,
    required String emoji,
    required int? reminderMinutes,
    required bool addPhoto,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const CalendarException('Inicia sesión primero.');
    final eventId = _db
        .collection('couples')
        .doc(coupleCode)
        .collection('calendarEvents')
        .doc()
        .id;
    String? photoPath;
    if (addPhoto) {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await _compress(picked.path);
      photoPath = 'couples/$coupleCode/calendar/$eventId/photo.jpg';
      try {
        await _storage
            .ref()
            .child(photoPath)
            .putData(
              bytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'coupleCode': coupleCode,
                  'eventId': eventId,
                  'uploadedBy': user.uid,
                },
              ),
            );
      } on FirebaseException {
        throw const CalendarException('No se pudo subir la foto del evento.');
      }
    }
    try {
      await _call('saveCalendarEvent', {
        'coupleCode': coupleCode,
        'eventId': eventId,
        'title': title.trim(),
        'description': description.trim(),
        'date': date.toUtc().toIso8601String(),
        'category': category.name,
        'emoji': emoji.trim(),
        'reminderMinutes': reminderMinutes,
        'photoPath': photoPath,
      });
    } catch (_) {
      if (photoPath != null) {
        try {
          await _call('discardCalendarUpload', {
            'coupleCode': coupleCode,
            'eventId': eventId,
          });
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> delete({required String coupleCode, required String eventId}) =>
      _call('deleteCalendarEvent', {
        'coupleCode': coupleCode,
        'eventId': eventId,
      });

  static List<CoupleEvent> upcoming(
    Iterable<CoupleEvent> events,
    DateTime now,
  ) =>
      events.where((event) => !event.date.isBefore(now)).toList(growable: false)
        ..sort((first, second) => first.date.compareTo(second.date));

  Future<Uint8List> loadPhoto(String path) async {
    try {
      final bytes = await _storage.ref().child(path).getData(maxPhotoBytes);
      if (bytes == null || bytes.isEmpty) {
        throw const CalendarException('Foto no disponible.');
      }
      return bytes;
    } on FirebaseException {
      throw const CalendarException('No se pudo cargar la foto.');
    }
  }

  Future<Uint8List> _compress(String path) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1280,
      minHeight: 1280,
      quality: 70,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (bytes == null || bytes.isEmpty || bytes.lengthInBytes > maxPhotoBytes) {
      throw const CalendarException('La foto no pudo optimizarse bajo 750 KB.');
    }
    return bytes;
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw CalendarException(
        error.message ?? 'No se pudo actualizar el calendario.',
      );
    }
  }
}
