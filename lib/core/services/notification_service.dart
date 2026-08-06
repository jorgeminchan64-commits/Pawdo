import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredUid;
  String? _registeredToken;
  void Function(RemoteMessage message)? _onForeground;
  void Function(RemoteMessage message)? _onOpenChat;

  Future<void> initialize({
    void Function(RemoteMessage message)? onForeground,
    void Function(RemoteMessage message)? onOpenChat,
  }) async {
    _onForeground = onForeground;
    _onOpenChat = onOpenChat;
    try {
      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        _saveToken,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FCM token refresh failed: $error\n$stackTrace');
        },
      );
      _authSubscription ??= _auth.authStateChanges().listen(
        (user) {
          if (user != null) unawaited(_registerWithoutPrompt());
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FCM auth listener failed: $error\n$stackTrace');
        },
      );
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        (message) => _onForeground?.call(message),
      );
      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpen,
      );
      await _registerWithoutPrompt();
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (error, stackTrace) {
      debugPrint('Notification initialization skipped: $error\n$stackTrace');
    }
  }

  Future<bool> requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final allowed = _allowed(settings.authorizationStatus);
      if (allowed) await _saveToken(await _messaging.getToken());
      return allowed;
    } catch (error, stackTrace) {
      debugPrint('Notification permission failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> unregisterBeforeLogout() async {
    final user = _auth.currentUser;
    final token = _registeredToken ?? await _messaging.getToken();
    if (user != null && token != null) {
      try {
        await _deviceRef(user.uid, token).delete();
      } catch (error, stackTrace) {
        debugPrint('FCM device unregister failed: $error\n$stackTrace');
      }
    }
    try {
      await _messaging.deleteToken();
    } catch (error, stackTrace) {
      debugPrint('FCM token deletion failed: $error\n$stackTrace');
    }
    _registeredUid = null;
    _registeredToken = null;
  }

  Future<void> _registerWithoutPrompt() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      if (_allowed(settings.authorizationStatus)) {
        await _saveToken(await _messaging.getToken());
      }
    } catch (error, stackTrace) {
      debugPrint('FCM registration skipped: $error\n$stackTrace');
    }
  }

  bool _allowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<void> _saveToken(String? token) async {
    final user = _auth.currentUser;
    if (user == null || token == null || token.length < 20) return;
    try {
      if (_registeredUid != null &&
          _registeredUid != user.uid &&
          _registeredToken != null) {
        await _deviceRef(_registeredUid!, _registeredToken!).delete();
      }
      await _deviceRef(user.uid, token).set({
        'token': token,
        'platform': 'android',
        'enabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _registeredUid = user.uid;
      _registeredToken = token;
    } catch (error, stackTrace) {
      debugPrint('FCM token save failed: $error\n$stackTrace');
    }
  }

  DocumentReference<Map<String, dynamic>> _deviceRef(String uid, String token) {
    final id = sha256.convert(utf8.encode(token)).toString();
    return _db.collection('users').doc(uid).collection('devices').doc(id);
  }

  void _handleOpen(RemoteMessage message) {
    if (message.data['coupleCode'] != null) _onOpenChat?.call(message);
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
