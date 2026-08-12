import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../models/memory_entry.dart';

class MemoryException implements Exception {
  const MemoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MemoryService {
  MemoryService({
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

  static const maxOriginalBytes = 1024 * 1024;
  static const maxThumbnailBytes = 250 * 1024;
  static const categories = MemoryCategory.values;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;
  final Map<String, Uint8List> _cache = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String coupleCode) => _db
      .collection('couples')
      .doc(coupleCode)
      .collection('memories')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots();

  Future<void> create({
    required String coupleCode,
    required String description,
    required DateTime date,
    required String place,
    required List<String> tags,
    required MemoryCategory category,
    ValueChanged<double>? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const MemoryException('Inicia sesión primero.');
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final memoryId = _db
        .collection('couples')
        .doc(coupleCode)
        .collection('memories')
        .doc()
        .id;
    final original = await _compress(picked.path, 1600, 76, maxOriginalBytes);
    final thumbnail = await _compress(picked.path, 420, 65, maxThumbnailBytes);
    final base = 'couples/$coupleCode/memories/$memoryId';
    final originalPath = '$base/original.jpg';
    final thumbnailPath = '$base/thumb.jpg';

    try {
      await _upload(
        originalPath,
        original,
        coupleCode,
        memoryId,
        user.uid,
        'original',
        (value) => onProgress?.call(value * .8),
      );
      await _upload(
        thumbnailPath,
        thumbnail,
        coupleCode,
        memoryId,
        user.uid,
        'thumbnail',
        (value) => onProgress?.call(.8 + value * .2),
      );
      await _call('finalizeMemory', {
        'coupleCode': coupleCode,
        'memoryId': memoryId,
        'description': description.trim(),
        'date': date.toUtc().toIso8601String(),
        'place': place.trim(),
        'tags': normalizeTags(tags),
        'category': category.name,
        'originalPath': originalPath,
        'thumbnailPath': thumbnailPath,
      });
    } catch (error) {
      try {
        await _call('discardMemoryUpload', {
          'coupleCode': coupleCode,
          'memoryId': memoryId,
        });
      } catch (_) {}
      if (error is MemoryException) rethrow;
      throw const MemoryException('No se pudo guardar el recuerdo.');
    }
  }

  Future<void> toggleFavorite({
    required String coupleCode,
    required String memoryId,
  }) => _call('toggleMemoryFavorite', {
    'coupleCode': coupleCode,
    'memoryId': memoryId,
  });

  Future<void> delete({required String coupleCode, required String memoryId}) =>
      _call('deleteMemory', {'coupleCode': coupleCode, 'memoryId': memoryId});

  Future<Uint8List> loadImage(
    String storagePath, {
    required int maxBytes,
  }) async {
    final cached = _cache[storagePath];
    if (cached != null) return cached;
    try {
      final bytes = await _storage.ref().child(storagePath).getData(maxBytes);
      if (bytes == null || bytes.isEmpty) {
        throw const MemoryException('La imagen ya no existe.');
      }
      _cache[storagePath] = bytes;
      return bytes;
    } on FirebaseException {
      throw const MemoryException('No se pudo cargar la imagen.');
    }
  }

  static List<String> normalizeTags(Iterable<String> values) => values
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty && value.length <= 30)
      .toSet()
      .take(10)
      .toList(growable: false);

  Future<Uint8List> _compress(
    String path,
    int dimension,
    int quality,
    int limit,
  ) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: dimension,
      minHeight: dimension,
      quality: quality,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (bytes == null || bytes.isEmpty || bytes.lengthInBytes > limit) {
      throw const MemoryException(
        'La foto no pudo optimizarse de forma segura.',
      );
    }
    return bytes;
  }

  Future<void> _upload(
    String path,
    Uint8List bytes,
    String code,
    String memoryId,
    String uid,
    String variant,
    ValueChanged<double> onProgress,
  ) async {
    final task = _storage
        .ref()
        .child(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'coupleCode': code,
              'memoryId': memoryId,
              'uploadedBy': uid,
              'variant': variant,
            },
          ),
        );
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await task;
    } on FirebaseException {
      throw const MemoryException('No se pudo subir la foto del recuerdo.');
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw MemoryException(
        error.code == 'not-found'
            ? 'El álbum necesita una actualización del servicio de Pawdo.'
            : error.message ?? 'No se pudo actualizar el álbum.',
      );
    }
  }
}
