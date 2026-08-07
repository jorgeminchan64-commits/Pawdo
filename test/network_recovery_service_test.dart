import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/services/network_recovery_service.dart';
import 'package:pawdo/core/widgets/network_status_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recovers registered work when transport returns', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    final service = NetworkRecoveryService(
      checkConnectivity: () async => const [ConnectivityResult.none],
      connectivityChanges: changes.stream,
      updatedDuration: const Duration(milliseconds: 5),
    );
    var recoveries = 0;
    service.registerRecoveryTask('test', () async => recoveries++);

    await service.start();
    expect(service.status, NetworkRecoveryStatus.offline);

    changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(recoveries, 1);
    expect(service.status, NetworkRecoveryStatus.online);

    await service.shutdown();
    await changes.close();
  });

  test('uses bounded backoff after a real operation fails', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    final service = NetworkRecoveryService(
      checkConnectivity: () async => const [ConnectivityResult.mobile],
      connectivityChanges: changes.stream,
      retryDelays: const [Duration(milliseconds: 5)],
      updatedDuration: const Duration(milliseconds: 20),
    );
    var attempts = 0;
    service.registerRecoveryTask('flaky', () async {
      attempts++;
      if (attempts == 1) throw StateError('simulated transient failure');
    });

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 12));

    expect(attempts, 2);
    expect(service.status, NetworkRecoveryStatus.updated);

    await service.shutdown();
    await changes.close();
  });

  test('checks transport again when the app resumes', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    var checks = 0;
    final service = NetworkRecoveryService(
      checkConnectivity: () async {
        checks++;
        return const [ConnectivityResult.wifi];
      },
      connectivityChanges: changes.stream,
      updatedDuration: const Duration(milliseconds: 5),
    );

    await service.start();
    expect(checks, 1);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(checks, 2);

    await service.shutdown();
    await changes.close();
  });

  testWidgets('shows an accessible reconnecting banner', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = NetworkRecoveryService(
      checkConnectivity: () async => const [ConnectivityResult.none],
      connectivityChanges: const Stream.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NetworkStatusBanner(service: service)),
      ),
    );

    expect(find.text('Reconectando…'), findsOneWidget);
    expect(find.bySemanticsLabel('Reconectando…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
