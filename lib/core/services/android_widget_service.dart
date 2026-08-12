import 'package:flutter/services.dart';

class WidgetDashboardData {
  const WidgetDashboardData({
    required this.daysTogether,
    required this.duration,
    required this.nextEvent,
    required this.petStatus,
  });
  final int daysTogether;
  final String duration;
  final String nextEvent;
  final String petStatus;

  String get title =>
      '$daysTogether ${daysTogether == 1 ? 'día' : 'días'} juntos ❤️';
  String get body => duration;
  String get activity => nextEvent.isNotEmpty ? nextEvent : petStatus;
}

class AndroidWidgetPreferences {
  const AndroidWidgetPreferences({
    required this.enabled,
    required this.showContent,
  });

  final bool enabled;
  final bool showContent;
}

class AndroidWidgetService {
  AndroidWidgetService._();
  static final instance = AndroidWidgetService._();

  static const MethodChannel _channel = MethodChannel('pawdo/android_widget');

  Future<void> updateDashboard({
    required WidgetDashboardData data,
    Uint8List? partnerPhoto,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': data.title,
        'body': data.body,
        'activity': data.activity,
      };
      if (partnerPhoto != null) payload['photo'] = partnerPhoto;
      await _channel.invokeMethod<void>('updateWidget', payload);
    } on PlatformException {
      // El widget es complementario y nunca debe bloquear la aplicación.
    } on MissingPluginException {
      // Solo Android implementa este canal.
    }
  }

  Future<String?> pendingAction() async {
    try {
      return await _channel.invokeMethod<String>('takePendingAction');
    } catch (_) {
      return null;
    }
  }

  Future<void> completePendingAction() async {
    try {
      await _channel.invokeMethod<void>('completePendingAction');
    } catch (_) {}
  }

  Future<AndroidWidgetPreferences> preferences() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getPreferences',
      );
      return AndroidWidgetPreferences(
        enabled: data?['enabled'] != false,
        showContent: data?['showContent'] == true,
      );
    } catch (_) {
      return const AndroidWidgetPreferences(enabled: true, showContent: false);
    }
  }

  Future<void> setPreferences({
    required bool enabled,
    required bool showContent,
  }) async {
    await _channel.invokeMethod<void>('setPreferences', {
      'enabled': enabled,
      'showContent': showContent,
    });
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearWidget');
    } catch (_) {
      // Cerrar sesión debe continuar aunque el widget no esté disponible.
    }
  }
}
