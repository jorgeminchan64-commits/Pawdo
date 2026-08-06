import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../chat/services/chat_service.dart';

enum SharedMediaError {
  unauthenticated,
  noCouple,
  coupleNotFound,
  notMember,
  tooLarge,
  unsupportedFormat,
  compression,
  upload,
  metadata,
  permissionDenied,
  connection,
  notFound,
  firebaseNotConfigured,
  unknown,
}

class SharedMediaException implements Exception {
  const SharedMediaException(this.error, this.message);

  final SharedMediaError error;
  final String message;

  @override
  String toString() => message;
}

class SharedMediaService {
  SharedMediaService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
    ChatService? chatService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker(),
       _chatService = chatService ?? ChatService();

  static const int maxImageBytes = 1 * 1024 * 1024;
  static const int maxSourceBytes = 25 * 1024 * 1024;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final ChatService _chatService;

  Future<void> captureAndShare(String coupleCode) =>
      pickAndShare(coupleCode, source: ImageSource.camera);

  Future<void> pickAndShare(
    String coupleCode, {
    required ImageSource source,
    ValueChanged<double>? onProgress,
  }) async {
    final user = await _requireMember(coupleCode);
    final picked = await _pickImage(source);
    if (picked == null) return;

    await _validateSourceImage(picked);
    final bytes = await compressFileToLimit(picked.path);
    final messageId = _chatService.newMessageId(coupleCode);
    final uniquePart = DateTime.now().microsecondsSinceEpoch;
    final fileName = '${uniquePart}_$messageId.jpg';
    final storagePath = 'couples/$coupleCode/photos/$fileName';
    final reference = _storage.ref().child(storagePath);

    try {
      final task = reference.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: <String, String>{
            'coupleCode': coupleCode,
            'uploadedBy': user.uid,
          },
        ),
      );
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
      try {
        await task;
      } finally {
        await subscription.cancel();
      }
    } on FirebaseException catch (error) {
      throw _firebaseError(error, fallback: SharedMediaError.upload);
    }

    try {
      await _chatService.finalizePhotoMetadata(
        messageId: messageId,
        coupleCode: coupleCode,
        storagePath: storagePath,
        fileName: fileName,
      );
    } catch (error, stackTrace) {
      try {
        await _chatService.discardPhotoUpload(
          coupleCode: coupleCode,
          storagePath: storagePath,
          fileName: fileName,
        );
      } catch (cleanupError, cleanupStackTrace) {
        debugPrint(
          'Shared photo cleanup failed for $storagePath: $cleanupError\n'
          '$cleanupStackTrace',
        );
      }
      debugPrint('Photo metadata failed: $error\n$stackTrace');
      final mapped = error is FirebaseException
          ? _firebaseError(error, fallback: SharedMediaError.metadata)
          : const SharedMediaException(
              SharedMediaError.metadata,
              'La foto no se guardó en el chat. Inténtalo nuevamente.',
            );
      throw SharedMediaException(
        mapped.error,
        mapped.error == SharedMediaError.permissionDenied
            ? mapped.message
            : 'La foto no se guardó en el chat. Inténtalo nuevamente.',
      );
    }
  }

  Future<Uint8List> loadPhoto({
    required String coupleCode,
    required String storagePath,
    required String cacheKey,
  }) async {
    await _requireMember(coupleCode);
    _validateStoragePath(coupleCode, storagePath);
    final cacheFile = await _photoCacheFile(coupleCode, cacheKey);
    if (await cacheFile.exists()) {
      final cached = await cacheFile.readAsBytes();
      if (cached.isNotEmpty && cached.lengthInBytes <= maxImageBytes) {
        return cached;
      }
      await cacheFile.delete().catchError((_) => cacheFile);
    }
    try {
      final bytes = await _storage
          .ref()
          .child(storagePath)
          .getData(maxImageBytes);
      if (bytes == null) {
        throw const SharedMediaException(
          SharedMediaError.notFound,
          'La fotografía ya no existe.',
        );
      }
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(bytes, flush: true);
      return bytes;
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  Future<void> deletePhoto({
    required String coupleCode,
    required String messageId,
    required String storagePath,
  }) async {
    await _requireMember(coupleCode);
    _validateStoragePath(coupleCode, storagePath);

    // Removing metadata first prevents a dangling chat bubble. The deployed
    // onDocumentDeleted function removes Storage and retries on transient errors.
    try {
      await _chatService.deleteMessage(
        coupleCode: coupleCode,
        messageId: messageId,
      );
    } on ChatException catch (error) {
      throw SharedMediaException(SharedMediaError.metadata, error.message);
    }
  }

  Future<void> clearCachedPhoto(String coupleCode, String cacheKey) async {
    final file = await _photoCacheFile(coupleCode, cacheKey);
    if (await file.exists()) await file.delete();
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(source: source);
    } catch (error, stackTrace) {
      debugPrint('Image picker failed: $error\n$stackTrace');
      throw const SharedMediaException(
        SharedMediaError.unknown,
        'No se pudo abrir la cámara.',
      );
    }
  }

  Future<void> _validateSourceImage(XFile image) async {
    try {
      if (await image.length() > maxSourceBytes) {
        throw const SharedMediaException(
          SharedMediaError.tooLarge,
          'La imagen original supera 25 MB.',
        );
      }
      final file = File(image.path);
      final handle = await file.open();
      Uint8List header;
      try {
        header = await handle.read(12);
      } finally {
        await handle.close();
      }
      if (!isSupportedImageHeader(header)) {
        throw const SharedMediaException(
          SharedMediaError.unsupportedFormat,
          'Selecciona una imagen JPEG, PNG o WebP.',
        );
      }
    } on SharedMediaException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Source image validation failed: $error\n$stackTrace');
      throw const SharedMediaException(
        SharedMediaError.unsupportedFormat,
        'No se pudo leer la imagen seleccionada.',
      );
    }
  }

  Future<File> _photoCacheFile(String coupleCode, String cacheKey) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{10,80}$').hasMatch(cacheKey)) {
      throw const SharedMediaException(
        SharedMediaError.permissionDenied,
        'La clave de caché no es válida.',
      );
    }
    final root = await getTemporaryDirectory();
    return File('${root.path}/pawdo_photos/$coupleCode/$cacheKey.jpg');
  }

  static Future<Uint8List> compressFileToLimit(String sourcePath) async {
    const attempts = <_CompressionAttempt>[
      _CompressionAttempt(1600, 82),
      _CompressionAttempt(1600, 68),
      _CompressionAttempt(1280, 60),
      _CompressionAttempt(1024, 52),
      _CompressionAttempt(800, 45),
    ];

    try {
      for (final attempt in attempts) {
        final result = await FlutterImageCompress.compressWithFile(
          sourcePath,
          minWidth: attempt.maxDimension,
          minHeight: attempt.maxDimension,
          quality: attempt.quality,
          rotate: 0,
          autoCorrectionAngle: true,
          keepExif: false,
          format: CompressFormat.jpeg,
        );
        if (result == null || result.isEmpty) continue;
        if (result.lengthInBytes <= maxImageBytes) return result;
      }
    } catch (error, stackTrace) {
      debugPrint('Image compression failed: $error\n$stackTrace');
      throw const SharedMediaException(
        SharedMediaError.compression,
        'No se pudo comprimir la imagen.',
      );
    }

    throw const SharedMediaException(
      SharedMediaError.tooLarge,
      'La imagen sigue superando 1 MB después de comprimirla.',
    );
  }

  Future<User> _requireMember(String coupleCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SharedMediaException(
        SharedMediaError.unauthenticated,
        'Debes iniciar sesión para compartir fotografías.',
      );
    }
    if (coupleCode.isEmpty) {
      throw const SharedMediaException(
        SharedMediaError.noCouple,
        'Conecta una pareja antes de compartir fotografías.',
      );
    }

    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(user.uid).get(),
        _firestore.collection('couples').doc(coupleCode).get(),
      ]);
      final userData = results[0].data();
      final coupleSnapshot = results[1];
      if (!coupleSnapshot.exists) {
        throw const SharedMediaException(
          SharedMediaError.coupleNotFound,
          'La pareja ya no existe.',
        );
      }
      final coupleData = coupleSnapshot.data();
      final profileCode = userData?['coupleCode']?.toString();
      final isMember =
          coupleData != null &&
          (coupleData['user1'] == user.uid || coupleData['user2'] == user.uid);
      if (profileCode != coupleCode || !isMember) {
        throw const SharedMediaException(
          SharedMediaError.notMember,
          'No perteneces a esta pareja.',
        );
      }
      return user;
    } on SharedMediaException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  void _validateStoragePath(String coupleCode, String storagePath) {
    final prefix = 'couples/$coupleCode/photos/';
    final fileName = storagePath.startsWith(prefix)
        ? storagePath.substring(prefix.length)
        : '';
    if (fileName.isEmpty || fileName.contains('/')) {
      throw const SharedMediaException(
        SharedMediaError.permissionDenied,
        'La ruta de la fotografía no es válida.',
      );
    }
  }

  static bool isSupportedImageHeader(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return true;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return true;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  SharedMediaException _firebaseError(
    FirebaseException error, {
    SharedMediaError fallback = SharedMediaError.unknown,
  }) {
    switch (error.code) {
      case 'unauthenticated':
        return const SharedMediaException(
          SharedMediaError.unauthenticated,
          'Debes iniciar sesión para continuar.',
        );
      case 'unauthorized':
      case 'permission-denied':
        return const SharedMediaException(
          SharedMediaError.permissionDenied,
          'Firebase rechazó el acceso a esta fotografía.',
        );
      case 'object-not-found':
        return const SharedMediaException(
          SharedMediaError.notFound,
          'La fotografía ya no existe.',
        );
      case 'retry-limit-exceeded':
      case 'network-request-failed':
      case 'unavailable':
        return const SharedMediaException(
          SharedMediaError.connection,
          'No se pudo conectar. Revisa tu conexión e inténtalo otra vez.',
        );
      case 'no-app':
      case 'core/no-app':
        return const SharedMediaException(
          SharedMediaError.firebaseNotConfigured,
          'Firebase no está disponible en este dispositivo.',
        );
      default:
        return SharedMediaException(
          fallback,
          fallback == SharedMediaError.upload
              ? 'No se pudo subir la fotografía.'
              : 'No se pudo completar la operación con la fotografía.',
        );
    }
  }
}

class _CompressionAttempt {
  const _CompressionAttempt(this.maxDimension, this.quality);

  final int maxDimension;
  final int quality;
}
