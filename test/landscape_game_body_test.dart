import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/widgets/landscape_game_body.dart';

void main() {
  testWidgets('asks for rotation instead of rendering game in portrait', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LandscapeGameBody(
          onExit: () {},
          landscapeChild: const Text('GAME'),
        ),
      ),
    );

    expect(find.text('Gira tu teléfono'), findsOneWidget);
    expect(find.text('GAME'), findsNothing);
  });

  testWidgets('renders game content in landscape', (tester) async {
    tester.view.physicalSize = const Size(720, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LandscapeGameBody(
          onExit: () {},
          landscapeChild: const Text('GAME'),
        ),
      ),
    );

    expect(find.text('GAME'), findsOneWidget);
    expect(find.text('Gira tu teléfono'), findsNothing);
  });
}
