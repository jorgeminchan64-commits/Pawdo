import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

class LocationSharingException implements Exception {
  const LocationSharingException(
    this.message, {
    this.settingsRequired = false,
    this.locationSettingsRequired = false,
    this.code,
  });
  final String message;
  final bool settingsRequired;
  final bool locationSettingsRequired;
  final String? code;
  @override
  String toString() => message;
}

class LocationShare {
  const LocationShare({
    required this.ownerUid,
    required this.sessionId,
    required this.mode,
    required this.approximate,
    required this.active,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.updatedAt,
    required this.endsAt,
    required this.expiresAt,
  });

  factory LocationShare.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : null;
    return LocationShare(
      ownerUid: data['ownerUid']?.toString() ?? document.id,
      sessionId: data['sessionId']?.toString() ?? '',
      mode: data['mode']?.toString() ?? 'point',
      approximate: data['approximate'] == true,
      active: data['active'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      accuracyMeters: (data['accuracyMeters'] as num?)?.toDouble(),
      updatedAt: date(data['locationUpdatedAt']),
      endsAt: date(data['endsAt']),
      expiresAt: date(data['expiresAt']),
    );
  }

  final String ownerUid;
  final String sessionId;
  final String mode;
  final bool approximate;
  final bool active;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? updatedAt;
  final DateTime? endsAt;
  final DateTime? expiresAt;

  bool get hasPosition => latitude != null && longitude != null;
  bool get expired {
    final expiry = expiresAt ?? endsAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }
}

class LocationSharingService with WidgetsBindingObserver {
  factory LocationSharingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) {
    if (auth == null && firestore == null && functions == null) return instance;
    return LocationSharingService._(
      auth: auth,
      firestore: firestore,
      functions: functions,
    );
  }

  LocationSharingService._({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  static final LocationSharingService instance = LocationSharingService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _endTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastPublishedAt;
  Position? _lastPosition;
  String? _sessionId;
  bool _approximate = false;
  bool _initialized = false;
  bool _publishing = false;

  String get currentUid => _auth.currentUser?.uid ?? '';

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        unawaited(_clearLocalSession());
      } else {
        unawaited(_restoreActiveShare());
      }
    });
  }

  Future<void> shutdown() async {
    if (!_initialized) return;
    _initialized = false;
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _clearLocalSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreActiveShare());
    } else {
      unawaited(_pauseTrackingOnly());
    }
  }

  Future<String> requireCoupleCode() async {
    final uid = currentUid;
    if (uid.isEmpty) {
      throw const LocationSharingException('Inicia sesión para continuar.');
    }
    final user = await _firestore.collection('users').doc(uid).get();
    final code = user.data()?['coupleCode']?.toString() ?? '';
    if (code.isEmpty) {
      throw const LocationSharingException(
        'Conecta a tu pareja para compartir ubicación.',
      );
    }
    return code;
  }

  Stream<List<LocationShare>> watchShares(String coupleCode) => _firestore
      .collection('couples')
      .doc(coupleCode)
      .collection('locationShares')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(LocationShare.fromDocument).toList(),
      );

  Future<void> start({required String mode, required bool approximate}) async {
    await _ensurePermission();
    // A GPS failure cannot leave an empty share document on the server.
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy:
          approximate ? LocationAccuracy.low : LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    final result = await _call('startLocationSharing', {
      'mode': mode,
      'approximate': approximate,
    });
    _sessionId = result['sessionId']?.toString();
    _approximate = approximate;
    if (_sessionId == null) {
      throw const LocationSharingException('No se creó la sesión.');
    }
    try {
      _lastPosition = position;
      await _publish(position);
    } catch (_) {
      try {
        await _call('stopLocationSharing', const {});
      } catch (_) {
        // The server safety expiry removes it if compensation cannot connect.
      }
      await _clearLocalSession();
      rethrow;
    }
    if (mode == 'point') return;
    await _startPositionStream();
    final duration = switch (mode) {
      '15m' => const Duration(minutes: 15),
      '1h' => const Duration(hours: 1),
      '8h' => const Duration(hours: 8),
      _ => null,
    };
    if (duration != null) {
      _endTimer?.cancel();
      _endTimer = Timer(duration, () => unawaited(stop()));
    }
  }

  Future<void> resume(LocationShare share) async {
    if (!share.active || share.expired || share.sessionId.isEmpty) return;
    if (!await _canUseLocationWithoutPrompt()) return;
    _sessionId = share.sessionId;
    _approximate = share.approximate;
    await _startPositionStream();
    if (share.endsAt != null) {
      final remaining = share.endsAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        await stop();
      } else {
        _endTimer?.cancel();
        _endTimer = Timer(remaining, () => unawaited(stop()));
      }
    }
  }

  Future<void> _startPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _approximate ? LocationAccuracy.low : LocationAccuracy.high,
        distanceFilter: _approximate ? 500 : 50,
      ),
    ).listen(
      (position) {
        _lastPosition = position;
        final last = _lastPublishedAt;
        if (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 25)) {
          return;
        }
        unawaited(_publishIfIdle(position));
      },
      onError: (_) => unawaited(_pauseTrackingOnly()),
    );
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final position = _lastPosition ?? await Geolocator.getLastKnownPosition();
      if (position != null) await _publishIfIdle(position);
    });
  }

  Future<void> _publishIfIdle(Position position) async {
    if (_publishing) return;
    _publishing = true;
    try {
      await _publish(position);
    } on LocationSharingException catch (error) {
      if (const {
        'unauthenticated',
        'permission-denied',
        'failed-precondition',
        'not-found',
      }.contains(error.code)) {
        await _clearLocalSession();
      }
      // Transient failures retry on the next movement or heartbeat.
    } finally {
      _publishing = false;
    }
  }

  Future<void> _publish(Position position) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final result = await _call('updateSharedLocation', {
      'sessionId': sessionId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    });
    if (result['accepted'] == true) _lastPublishedAt = DateTime.now();
    if (result['expired'] == true) await _clearLocalSession();
  }

  Future<void> stop() async {
    await _pauseTrackingOnly();
    _endTimer?.cancel();
    _endTimer = null;
    try {
      await _call('stopLocationSharing', const {});
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> pauseLocalUpdates() async {
    await _pauseTrackingOnly();
    _endTimer?.cancel();
    _endTimer = null;
  }

  Future<void> _pauseTrackingOnly() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _clearLocalSession() async {
    await pauseLocalUpdates();
    _sessionId = null;
    _lastPublishedAt = null;
    _lastPosition = null;
  }

  Future<bool> _canUseLocationWithoutPrompt() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _restoreActiveShare() async {
    final uid = currentUid;
    if (uid.isEmpty || !await _canUseLocationWithoutPrompt()) return;
    try {
      final user = await _firestore.collection('users').doc(uid).get();
      final code = user.data()?['coupleCode']?.toString() ?? '';
      if (code.isEmpty) {
        await _clearLocalSession();
        return;
      }
      final document = await _firestore
          .collection('couples')
          .doc(code)
          .collection('locationShares')
          .doc(uid)
          .get();
      if (!document.exists) {
        await _clearLocalSession();
        return;
      }
      final share = LocationShare.fromDocument(document);
      if (!share.active || share.expired) {
        await _clearLocalSession();
        return;
      }
      await resume(share);
    } catch (_) {
      // Opening the location screen provides another recovery opportunity.
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationSharingException(
        'La ubicación del teléfono está desactivada.',
        settingsRequired: true,
        locationSettingsRequired: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationSharingException(
        permission == LocationPermission.deniedForever
            ? 'El permiso fue bloqueado. Actívalo desde Ajustes de Android.'
            : 'Sin permiso no se compartirá ninguna ubicación.',
        settingsRequired: permission == LocationPermission.deniedForever,
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (error) {
      throw LocationSharingException(
        error.message ?? 'No se pudo actualizar la ubicación.',
        code: error.code,
      );
    } on FirebaseException catch (error) {
      throw LocationSharingException(
        error.message ?? 'Error de conexión con Pawdo.',
      );
    } catch (_) {
      throw const LocationSharingException(
        'No se pudo completar la operación.',
      );
    }
  }
}
