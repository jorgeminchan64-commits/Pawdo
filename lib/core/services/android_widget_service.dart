import 'package:flutter/services.dart';

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
    required int energy,
    required int streak,
    String? lastActivity,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'title': 'Pawdo está esperando 🐾',
        'body': 'Energía $energy% · Racha $streak días',
        'activity': lastActivity?.trim() ?? '',
      });
    } on PlatformException {
      // El widget es complementario y nunca debe bloquear la aplicación.
    } on MissingPluginException {
      // Solo Android implementa este canal.
    }
  }

  Future<AndroidWidgetPreferences> preferences() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getPreferences');
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
