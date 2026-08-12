import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/services/app_check_service.dart';

void main() {
  test('debug builds use only the App Check debug provider', () {
    expect(
      appCheckProviderFor(
        platform: TargetPlatform.android,
        debug: true,
        web: false,
      ),
      PawdoAppCheckProvider.debug,
    );
  });

  test('Android release builds use Play Integrity', () {
    expect(
      appCheckProviderFor(
        platform: TargetPlatform.android,
        debug: false,
        web: false,
      ),
      PawdoAppCheckProvider.playIntegrity,
    );
  });

  test('unsupported clients never masquerade as an attested platform', () {
    expect(
      appCheckProviderFor(
        platform: TargetPlatform.windows,
        debug: false,
        web: false,
      ),
      PawdoAppCheckProvider.unsupported,
    );
    expect(
      appCheckProviderFor(
        platform: TargetPlatform.android,
        debug: false,
        web: true,
      ),
      PawdoAppCheckProvider.unsupported,
    );
  });
}
