import 'dart:convert';
import 'dart:math';

abstract final class PawdoBridgeMessageTypes {
  static const flutterToUnity = <String>{
    'runtime.initialize',
    'session.context',
    'scene.load',
    'scene.pause',
    'scene.resume',
    'scene.unload',
    'avatar.appearance',
    'pet.snapshot',
    'inventory.snapshot',
    'layout.snapshot',
    'interaction.result',
    'voice.permission',
    'voice.level',
    'voice.playback',
  };

  static const unityToFlutter = <String>{
    'runtime.ready',
    'runtime.error',
    'scene.ready',
    'interaction.request',
    'layout.save.request',
    'voice.start.request',
    'voice.stop.request',
    'navigation.exit',
    'telemetry.sample',
  };

  static bool isKnown(String type) {
    return flutterToUnity.contains(type) || unityToFlutter.contains(type);
  }
}

class PawdoBridgeFormatException implements FormatException {
  const PawdoBridgeFormatException(this.code);

  final String code;

  @override
  String get message => code;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'PawdoBridgeFormatException($code)';
}

class PawdoBridgeEnvelope {
  const PawdoBridgeEnvelope({
    required this.schemaVersion,
    required this.messageId,
    required this.correlationId,
    required this.type,
    required this.sentAtEpochMs,
    required this.payload,
  });

  factory PawdoBridgeEnvelope.create({
    required String type,
    required Map<String, dynamic> payload,
    String? correlationId,
    DateTime? sentAt,
  }) {
    if (!PawdoBridgeMessageTypes.isKnown(type)) {
      throw const PawdoBridgeFormatException('unknown-message-type');
    }
    return PawdoBridgeEnvelope(
      schemaVersion: currentSchemaVersion,
      messageId: _secureUuidV4(),
      correlationId: correlationId,
      type: type,
      sentAtEpochMs: (sentAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
      payload: Map.unmodifiable(payload),
    );
  }

  factory PawdoBridgeEnvelope.decode(String rawJson) {
    if (utf8.encode(rawJson).length > maximumUtf8Bytes) {
      throw const PawdoBridgeFormatException('message-too-large');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      throw const PawdoBridgeFormatException('invalid-json');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PawdoBridgeFormatException('root-must-be-object');
    }

    const requiredKeys = {
      'schemaVersion',
      'messageId',
      'correlationId',
      'type',
      'sentAtEpochMs',
      'payload',
    };
    if (decoded.length != requiredKeys.length ||
        !decoded.keys.toSet().containsAll(requiredKeys)) {
      throw const PawdoBridgeFormatException('invalid-envelope-fields');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != currentSchemaVersion) {
      throw const PawdoBridgeFormatException('unsupported-schema-version');
    }
    final messageId = decoded['messageId'];
    if (messageId is! String || !_uuidPattern.hasMatch(messageId)) {
      throw const PawdoBridgeFormatException('invalid-message-id');
    }
    final correlationId = decoded['correlationId'];
    if (correlationId != null &&
        (correlationId is! String || !_uuidPattern.hasMatch(correlationId))) {
      throw const PawdoBridgeFormatException('invalid-correlation-id');
    }
    final type = decoded['type'];
    if (type is! String || !PawdoBridgeMessageTypes.isKnown(type)) {
      throw const PawdoBridgeFormatException('unknown-message-type');
    }
    final sentAtEpochMs = decoded['sentAtEpochMs'];
    if (sentAtEpochMs is! int || sentAtEpochMs <= 0) {
      throw const PawdoBridgeFormatException('invalid-sent-at');
    }
    final payload = decoded['payload'];
    if (payload is! Map<String, dynamic>) {
      throw const PawdoBridgeFormatException('payload-must-be-object');
    }

    return PawdoBridgeEnvelope(
      schemaVersion: schemaVersion,
      messageId: messageId,
      correlationId: correlationId as String?,
      type: type,
      sentAtEpochMs: sentAtEpochMs,
      payload: Map.unmodifiable(payload),
    );
  }

  static const currentSchemaVersion = 1;
  static const maximumUtf8Bytes = 64 * 1024;
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final int schemaVersion;
  final String messageId;
  final String? correlationId;
  final String type;
  final int sentAtEpochMs;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'messageId': messageId,
    'correlationId': correlationId,
    'type': type,
    'sentAtEpochMs': sentAtEpochMs,
    'payload': payload,
  };

  String encode() {
    final value = jsonEncode(toJson());
    if (utf8.encode(value).length > maximumUtf8Bytes) {
      throw const PawdoBridgeFormatException('message-too-large');
    }
    return value;
  }
}

String _secureUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
