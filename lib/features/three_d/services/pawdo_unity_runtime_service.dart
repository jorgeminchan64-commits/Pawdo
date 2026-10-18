import 'package:flutter/services.dart';

import '../bridge/pawdo_bridge_envelope.dart';
import '../models/pawdo_3d_scene.dart';

class PawdoUnityCapabilities {
  const PawdoUnityCapabilities({
    required this.available,
    required this.bridgeSchemaVersion,
    this.supportedScenes = const {},
    this.reason,
  });

  factory PawdoUnityCapabilities.fromMap(Map<Object?, Object?> values) {
    return PawdoUnityCapabilities(
      available: values['available'] == true,
      bridgeSchemaVersion: values['bridgeSchemaVersion'] as int? ?? 0,
      reason: values['reason'] as String?,
      supportedScenes: {
        if (values['supportedScenes'] case final List scenes)
          for (final scene in Pawdo3DScene.values)
            if (scenes.contains(scene.wireName)) scene,
      },
    );
  }

  final bool available;
  final int bridgeSchemaVersion;
  final String? reason;
  final Set<Pawdo3DScene> supportedScenes;
}

class PawdoUnityRuntimeService {
  const PawdoUnityRuntimeService();

  static const _channel = MethodChannel('pawdo/unity_runtime');

  Future<PawdoUnityCapabilities> capabilities() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'capabilities',
      );
      return PawdoUnityCapabilities.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return PawdoUnityCapabilities(
        available: false,
        bridgeSchemaVersion: 0,
        reason: error.code,
      );
    } on MissingPluginException {
      return const PawdoUnityCapabilities(
        available: false,
        bridgeSchemaVersion: 0,
        reason: 'missing-native-plugin',
      );
    }
  }

  Future<bool> launch(Pawdo3DScene scene) async {
    final runtime = await capabilities();
    if (!runtime.available ||
        runtime.bridgeSchemaVersion != 1 ||
        !runtime.supportedScenes.contains(scene)) {
      return false;
    }
    final initialize = PawdoBridgeEnvelope.create(
      type: 'runtime.initialize',
      payload: {
        'appVersion': '1.0.0+1',
        'locale': 'es-PE',
        'targetQuality': 'mobile-balanced',
        'scene': scene.wireName,
      },
    );
    try {
      return await _channel.invokeMethod<bool>('launch', {
            'scene': scene.wireName,
            'initializationEnvelope': initialize.encode(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> pause({String reason = 'flutter-paused'}) {
    return _sendLifecycle('scene.pause', {'reason': reason});
  }

  Future<bool> resume({int canonicalRevision = 0}) {
    return _sendLifecycle('scene.resume', {
      'canonicalRevision': canonicalRevision,
    });
  }

  Future<bool> unload({String reason = 'flutter-closed'}) {
    return _sendLifecycle('scene.unload', {'reason': reason});
  }

  Future<bool> sendVoiceLevel({
    required double rms,
    required double peak,
    required bool active,
  }) {
    return _sendEnvelope('voice.level', {
      'active': active,
      'rms': rms.clamp(0.0, 1.0),
      'peak': peak.clamp(0.0, 1.0),
    });
  }

  Future<bool> setVoicePlayback({required bool active}) {
    return _sendEnvelope('voice.playback', {
      'active': active,
      'rms': 0.0,
      'peak': 0.0,
    });
  }

  Future<bool> _sendLifecycle(String type, Map<String, Object?> payload) async {
    return _sendEnvelope(type, payload);
  }

  Future<bool> _sendEnvelope(String type, Map<String, Object?> payload) async {
    final envelope = PawdoBridgeEnvelope.create(type: type, payload: payload);
    try {
      return await _channel.invokeMethod<bool>('send', {
            'envelope': envelope.encode(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
