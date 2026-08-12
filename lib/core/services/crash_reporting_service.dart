import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class PawdoReportedError implements Exception {
  const PawdoReportedError(this.sourceType);

  final String sourceType;

  @override
  String toString() => 'PawdoUnhandledError<$sourceType>';
}

class CrashReportingService {
  CrashReportingService({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  static CrashReportingService instance = CrashReportingService();

  final FirebaseCrashlytics _crashlytics;
  bool _ready = false;

  Future<void> initialize() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    _ready = !kDebugMode;
  }

  void record(Object error, StackTrace stackTrace, {required bool fatal}) {
    if (kDebugMode) {
      debugPrint('Unhandled error: $error\n$stackTrace');
      return;
    }
    if (!_ready) {
      debugPrint(
        'Unhandled error before crash reporting was ready: '
        '${error.runtimeType}',
      );
      return;
    }
    unawaited(
      _crashlytics.recordError(
        PawdoReportedError(error.runtimeType.toString()),
        stackTrace,
        fatal: fatal,
        printDetails: false,
      ),
    );
  }
}
