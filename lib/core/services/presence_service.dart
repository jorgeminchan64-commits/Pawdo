import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../features/couple/services/couple_service.dart';

class PresenceService with WidgetsBindingObserver {
  static const heartbeatInterval = Duration(minutes: 2);

  PresenceService(this._coupleService, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final CoupleService _coupleService;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;
  Timer? _heartbeat;
  Future<void> _serial = Future.value();
  bool _resumed = true;
  bool? _lastSentOnline;
  DateTime? _lastSentAt;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _authSubscription = _auth.authStateChanges().listen((user) {
      _lastSentOnline = null;
      _lastSentAt = null;
      _sync(force: true);
    });
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _sync(force: true));
    _sync(force: true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    unawaited(_authSubscription?.cancel());
    if (_auth.currentUser != null) _enqueue(false);
  }

  Future<void> recover() async {
    _sync(force: true);
    await _serial;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_resumed == resumed) return;
    _resumed = resumed;
    _sync(force: true);
  }

  void _sync({bool force = false}) {
    if (_auth.currentUser == null) return;
    final online = _resumed;
    final fresh =
        _lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) < const Duration(seconds: 60);
    if (!force && _lastSentOnline == online && fresh) return;
    _enqueue(online);
  }

  void _enqueue(bool online) {
    _serial = _serial.then((_) async {
      try {
        await _coupleService.setPresence(online);
        _lastSentOnline = online;
        _lastSentAt = DateTime.now();
      } catch (error) {
        debugPrint('No se pudo actualizar la presencia: $error');
      }
    });
  }
}
