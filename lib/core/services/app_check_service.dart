import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

enum PawdoAppCheckProvider { debug, playIntegrity, deviceCheck, unsupported }

PawdoAppCheckProvider appCheckProviderFor({
  required TargetPlatform platform,
  required bool debug,
  required bool web,
}) {
  if (web) return PawdoAppCheckProvider.unsupported;
  if (debug) return PawdoAppCheckProvider.debug;
  return switch (platform) {
    TargetPlatform.android => PawdoAppCheckProvider.playIntegrity,
    TargetPlatform.iOS ||
    TargetPlatform.macOS => PawdoAppCheckProvider.deviceCheck,
    _ => PawdoAppCheckProvider.unsupported,
  };
}

class AppCheckService {
  AppCheckService({FirebaseAppCheck? appCheck})
    : _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAppCheck _appCheck;

  Future<void> activate() async {
    final provider = appCheckProviderFor(
      platform: defaultTargetPlatform,
      debug: kDebugMode,
      web: kIsWeb,
    );
    if (provider == PawdoAppCheckProvider.unsupported) return;

    await _appCheck.activate(
      androidProvider: provider == PawdoAppCheckProvider.debug
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: provider == PawdoAppCheckProvider.debug
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );
    await _appCheck.setTokenAutoRefreshEnabled(true);
  }
}
