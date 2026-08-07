import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

enum NetworkRecoveryStatus { online, offline, reconnecting, updated }

typedef NetworkRecoveryTask = Future<void> Function();

class NetworkRecoveryService with WidgetsBindingObserver {
  NetworkRecoveryService({
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ],
    this.updatedDuration = const Duration(seconds: 2),
  }) {
    final connectivity = Connectivity();
    _checkConnectivity = checkConnectivity ?? connectivity.checkConnectivity;
    _connectivityChanges =
        connectivityChanges ?? connectivity.onConnectivityChanged;
  }

  static final NetworkRecoveryService instance = NetworkRecoveryService();

  late final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  late final Stream<List<ConnectivityResult>> _connectivityChanges;
  final List<Duration> retryDelays;
  final Duration updatedDuration;
  final Map<String, NetworkRecoveryTask> _tasks = {};
  final StreamController<NetworkRecoveryStatus> _statusController =
      StreamController<NetworkRecoveryStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  Timer? _updatedTimer;
  NetworkRecoveryStatus _status = NetworkRecoveryStatus.reconnecting;
  bool _started = false;
  bool _transportAvailable = false;
  bool _recovering = false;
  int _retryAttempt = 0;

  NetworkRecoveryStatus get status => _status;
  Stream<NetworkRecoveryStatus> get statuses => _statusController.stream;

  Future<void> start() async {
    if (_started) {
      await refreshTransport();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivityChanges.listen(
      _handleConnectivity,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Connectivity stream error: ${error.runtimeType}');
        reportTransientFailure();
      },
    );
    await refreshTransport();
  }

  VoidCallback registerRecoveryTask(String id, NetworkRecoveryTask task) {
    _tasks[id] = task;
    return () {
      if (identical(_tasks[id], task)) _tasks.remove(id);
    };
  }

  Future<void> refreshTransport() async {
    try {
      _handleConnectivity(await _checkConnectivity());
    } catch (error) {
      debugPrint('Connectivity check error: ${error.runtimeType}');
      reportTransientFailure();
    }
  }

  void reportTransientFailure() {
    if (!_started) return;
    _setStatus(
      _transportAvailable
          ? NetworkRecoveryStatus.reconnecting
          : NetworkRecoveryStatus.offline,
    );
    if (_transportAvailable) {
      _scheduleRetry();
    } else {
      unawaited(refreshTransport());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshTransport());
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final available =
        results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
    final recoveredTransport = available && !_transportAvailable;
    _transportAvailable = available;

    if (!available) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _updatedTimer?.cancel();
      _retryAttempt = 0;
      _setStatus(NetworkRecoveryStatus.offline);
      return;
    }

    if (recoveredTransport) _retryAttempt = 0;
    if (recoveredTransport || _status == NetworkRecoveryStatus.reconnecting) {
      unawaited(_runRecovery());
    }
  }

  Future<void> _runRecovery() async {
    if (_recovering || !_transportAvailable) return;
    _recovering = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _setStatus(NetworkRecoveryStatus.reconnecting);
    var succeeded = true;

    for (final task in List<NetworkRecoveryTask>.of(_tasks.values)) {
      try {
        await task();
      } catch (error) {
        succeeded = false;
        debugPrint('Network recovery task failed: ${error.runtimeType}');
      }
    }

    _recovering = false;
    if (!_transportAvailable) return;
    if (!succeeded) {
      _scheduleRetry();
      return;
    }

    _retryAttempt = 0;
    _setStatus(NetworkRecoveryStatus.updated);
    _updatedTimer?.cancel();
    _updatedTimer = Timer(updatedDuration, () {
      if (_transportAvailable) _setStatus(NetworkRecoveryStatus.online);
    });
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _recovering || !_transportAvailable) return;
    if (_retryAttempt >= retryDelays.length) return;
    final delay = retryDelays[_retryAttempt];
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_runRecovery());
    });
  }

  void _setStatus(NetworkRecoveryStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  Future<void> shutdown() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _updatedTimer?.cancel();
    _updatedTimer = null;
  }

  Future<void> dispose() async {
    await shutdown();
    await _statusController.close();
  }
}
