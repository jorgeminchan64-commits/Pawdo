import 'package:flutter/services.dart';

class CallCapabilities {
  const CallCapabilities({
    required this.cameraAvailable,
    required this.microphoneAvailable,
    required this.cameraPermission,
    required this.microphonePermission,
  });

  factory CallCapabilities.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return CallCapabilities(
      cameraAvailable: map['cameraAvailable'] == true,
      microphoneAvailable: map['microphoneAvailable'] == true,
      cameraPermission: map['cameraPermission'] == true,
      microphonePermission: map['microphonePermission'] == true,
    );
  }

  final bool cameraAvailable;
  final bool microphoneAvailable;
  final bool cameraPermission;
  final bool microphonePermission;
}

class HardwareProbeResult {
  const HardwareProbeResult({required this.success, this.level});

  factory HardwareProbeResult.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return HardwareProbeResult(
      success: map['success'] == true,
      level: (map['level'] as num?)?.toDouble(),
    );
  }

  final bool success;
  final double? level;
}

class CallReadinessService {
  static const _channel = MethodChannel('pawdo/call_readiness');

  Future<CallCapabilities> capabilities() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('capabilities');
    return CallCapabilities.fromMap(data);
  }

  Future<CallCapabilities> requestPermissions() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('requestPermissions');
    return CallCapabilities.fromMap(data);
  }

  Future<HardwareProbeResult> probeMicrophone() async {
    final data = await _channel.invokeMapMethod<String, dynamic>(
      'probeMicrophone',
    );
    return HardwareProbeResult.fromMap(data);
  }

  Future<HardwareProbeResult> probeCamera() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('probeCamera');
    return HardwareProbeResult.fromMap(data);
  }
}
