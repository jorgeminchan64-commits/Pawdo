import 'package:flutter/services.dart';

class LocalVoiceRepeatException implements Exception {
  const LocalVoiceRepeatException(this.message, {this.code = 'voice-failed'});

  final String code;
  final String message;

  @override
  String toString() => message;
}

class LocalVoiceLevel {
  const LocalVoiceLevel({
    required this.recording,
    required this.playing,
    required this.rms,
    required this.peak,
    required this.voiceDetected,
  });

  factory LocalVoiceLevel.fromMap(Map<Object?, Object?> map) => LocalVoiceLevel(
    recording: map['recording'] == true,
    playing: map['playing'] == true,
    rms: ((map['rms'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
    peak: ((map['peak'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
    voiceDetected: map['voiceDetected'] == true,
  );

  final bool recording;
  final bool playing;
  final double rms;
  final double peak;
  final bool voiceDetected;
}

class LocalVoicePlaybackResult {
  const LocalVoicePlaybackResult({
    required this.duration,
    required this.temporaryDeleted,
    required this.uploaded,
  });

  factory LocalVoicePlaybackResult.fromMap(Map<Object?, Object?> map) =>
      LocalVoicePlaybackResult(
        duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
        temporaryDeleted: map['temporaryDeleted'] == true,
        uploaded: map['uploaded'] == true,
      );

  final Duration duration;
  final bool temporaryDeleted;
  final bool uploaded;
}

class LocalVoiceRepeatService {
  const LocalVoiceRepeatService();

  static const MethodChannel _channel = MethodChannel('pawdo/local_voice');

  Future<void> requestPermissionAndStart() async {
    try {
      final capabilities =
          await _channel.invokeMapMethod<Object?, Object?>('capabilities') ??
          const {};
      if (capabilities['available'] != true) {
        throw const LocalVoiceRepeatException(
          'Este dispositivo no informa un micrófono disponible.',
          code: 'microphone-unavailable',
        );
      }
      var granted = capabilities['permission'] == true;
      if (!granted) {
        granted =
            await _channel.invokeMethod<bool>('requestPermission') ?? false;
      }
      if (!granted) {
        throw const LocalVoiceRepeatException(
          'Autoriza el micrófono para que Pawdo repita tu voz.',
          code: 'permission-denied',
        );
      }
      final started =
          await _channel.invokeMapMethod<Object?, Object?>('start') ?? const {};
      if (started['accepted'] != true) {
        throw LocalVoiceRepeatException(
          started['reason'] == 'voice-busy'
              ? 'Pawdo todavía está reproduciendo la voz anterior.'
              : 'No se pudo iniciar el micrófono.',
          code: started['reason']?.toString() ?? 'voice-start-failed',
        );
      }
    } on PlatformException catch (error) {
      throw LocalVoiceRepeatException(
        error.message ?? 'No se pudo usar el micrófono.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const LocalVoiceRepeatException(
        'La voz local no está disponible en esta instalación.',
        code: 'voice-unavailable',
      );
    }
  }

  Future<LocalVoiceLevel> level() async {
    try {
      final values =
          await _channel.invokeMapMethod<Object?, Object?>('level') ?? const {};
      return LocalVoiceLevel.fromMap(values);
    } on PlatformException catch (error) {
      throw LocalVoiceRepeatException(
        error.message ?? 'Se interrumpió la lectura del micrófono.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const LocalVoiceRepeatException(
        'La voz local no está disponible en esta instalación.',
        code: 'voice-unavailable',
      );
    }
  }

  Future<LocalVoicePlaybackResult> stopAndPlay() async {
    try {
      final values =
          await _channel.invokeMapMethod<Object?, Object?>('stopAndPlay') ??
          const {};
      final result = LocalVoicePlaybackResult.fromMap(values);
      if (!result.temporaryDeleted || result.uploaded) {
        throw const LocalVoiceRepeatException(
          'La sesión local no terminó de forma segura.',
          code: 'voice-privacy-contract',
        );
      }
      return result;
    } on PlatformException catch (error) {
      throw LocalVoiceRepeatException(
        error.message ?? 'No se pudo reproducir la voz.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const LocalVoiceRepeatException(
        'La voz local no está disponible en esta instalación.',
        code: 'voice-unavailable',
      );
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Native cleanup is also enforced on Android onStop/onDestroy.
    } on MissingPluginException {
      // No native temporary file exists when the plugin is unavailable.
    }
  }
}
