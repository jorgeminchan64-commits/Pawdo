import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/main.dart';

void main() {
  testWidgets('shows a loading state until initialization completes', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      PawdoBootstrap(
        initialize: () => initialization.future,
        appBuilder: (_) => const MaterialApp(home: Text('Pawdo lista')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pawdo lista'), findsNothing);

    initialization.complete();
    await tester.pumpAndSettle();

    expect(find.text('Pawdo lista'), findsOneWidget);
  });

  testWidgets('offers retry and recovers after initialization fails', (
    tester,
  ) async {
    var attempts = 0;

    Future<void> initialize() async {
      attempts++;
      if (attempts == 1) throw StateError('simulated startup failure');
    }

    await tester.pumpWidget(
      PawdoBootstrap(
        initialize: initialize,
        appBuilder: (_) => const MaterialApp(home: Text('Pawdo lista')),
        onInitializationError: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar Pawdo'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Pawdo lista'), findsOneWidget);
  });
}
