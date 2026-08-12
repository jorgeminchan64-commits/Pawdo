import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../chat/services/chat_service.dart';

class AudioDraft {
  const AudioDraft({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

class AudioMessageException implements Exception {
  const AudioMessageException(this.message, {this.connection = false});

  final String message;
  final bool connection;

  @override
  String toString() => message;
}

class AudioMessageService {
  AudioMessageService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    ChatService? chatService,
    AudioRecorder? recorder,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _chatService = chatService ?? ChatService(),
       _recorder = recorder ?? AudioRecorder();

  static const maxDuration = Duration(seconds: 60);
  static const maxAudioBytes = 2 * 1024 * 1024;

  static bool isValidDuration(Duration duration) =>
      duration.inMilliseconds >= 500 && duration <= maxDuration;

  static bool isValidStoragePath(String coupleCode, String storagePath) {
    final expectedPrefix = 'couples/$coupleCode/audio/';
    return storagePath.startsWith(expectedPrefix) &&
        !storagePath.substring(expectedPrefix.length).contains('/') &&
        storagePath.endsWith('.m4a');
  }

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final ChatService _chatService;
  final AudioRecorder _recorder;
  DateTime? _startedAt;

  Future<void> start() async {
    if (_auth.currentUser == null) {
      throw const AudioMessageException('Inicia sesión para enviar audio.');
    }
    if (await _recorder.isRecording()) return;
    if (!await _recorder.hasPermission()) {
      throw const AudioMessageException(
        'Activa el permiso de micrófono para grabar un mensaje.',
      );
    }
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}pawdo_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 22050,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
  }

  Future<AudioDraft?> stop() async {
    final startedAt = _startedAt;
    final path = await _recorder.stop();
    _startedAt = null;
    if (path == null || startedAt == null) return null;
    final elapsed = DateTime.now().difference(startedAt);
    return AudioDraft(
      path: path,
      duration: elapsed > maxDuration ? maxDuration : elapsed,
    );
  }

  Future<void> cancel() async {
    _startedAt = null;
    await _recorder.cancel();
  }

  Future<void> upload(
    String coupleCode,
    AudioDraft draft, {
    ValueChanged<double>? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AudioMessageException('Inicia sesión para enviar audio.');
    }
    final durationMs = draft.duration.inMilliseconds;
    if (!isValidDuration(draft.duration)) {
      throw const AudioMessageException(
        'El audio debe durar entre 1 y 60 segundos.',
      );
    }
    final file = File(draft.path);
    final size = await file.length();
    if (size <= 0 || size > maxAudioBytes) {
      throw const AudioMessageException(
        'El audio supera el límite seguro de 2 MB.',
      );
    }
    final messageId = _chatService.newMessageId(coupleCode);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${user.uid}_$messageId.m4a';
    final storagePath = 'couples/$coupleCode/audio/$fileName';
    final reference = _storage.ref().child(storagePath);

    try {
      final task = reference.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/mp4',
          customMetadata: {
            'coupleCode': coupleCode,
            'uploadedBy': user.uid,
            'durationMs': '$durationMs',
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
      await _chatService.finalizeAudioMetadata(
        messageId: messageId,
        coupleCode: coupleCode,
        storagePath: storagePath,
        fileName: fileName,
        durationMs: durationMs,
      );
    } on FirebaseException catch (error) {
      throw AudioMessageException(
        error.code == 'unauthorized'
            ? 'No tienes permiso para compartir este audio.'
            : 'No se pudo subir el audio. Revisa tu conexión.',
        connection: error.code != 'unauthorized',
      );
    } on ChatException catch (error) {
      try {
        await _chatService.discardAudioUpload(
          coupleCode: coupleCode,
          storagePath: storagePath,
          fileName: fileName,
        );
      } catch (cleanupError) {
        debugPrint('Audio cleanup failed: $cleanupError');
      }
      throw AudioMessageException(error.message, connection: error.retryable);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> load({
    required String coupleCode,
    required String storagePath,
    required String cacheKey,
  }) async {
    if (!isValidStoragePath(coupleCode, storagePath)) {
      throw const AudioMessageException('La ruta del audio no es válida.');
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}pawdo_audio_$cacheKey.m4a',
    );
    if (await file.exists() && await file.length() > 0) return file;
    try {
      await _storage.ref().child(storagePath).writeToFile(file);
      if (await file.length() <= 0 || await file.length() > maxAudioBytes) {
        await file.delete();
        throw const AudioMessageException('El audio recibido no es válido.');
      }
      return file;
    } on FirebaseException catch (_) {
      throw const AudioMessageException(
        'No se pudo cargar el audio. Revisa tu conexión.',
        connection: true,
      );
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
