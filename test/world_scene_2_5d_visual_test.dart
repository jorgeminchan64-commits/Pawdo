import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/interior/game/pawdo_interior_game.dart';
import 'package:pawdo/features/world/game/pawdo_world_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('garden keeps the approved professional 2.5D composition', (
    tester,
  ) async {
    final game = PawdoWorldGame(
      onOpenInterior: () {},
      onWorldReward: (_) async {},
      onLayoutChanged: () {},
    );
    await _pumpScene(tester, game, const ValueKey('garden_2_5d'));

    await expectLater(
      find.byKey(const ValueKey('garden_2_5d')),
      matchesGoldenFile('goldens/garden_scene_2_5d.png'),
    );
  });

  testWidgets('interior keeps the approved professional 2.5D composition', (
    tester,
  ) async {
    final game = PawdoInteriorGame(
      onInteriorReward: (_) async {},
      onOpenCinema: () {},
      onLayoutChanged: () {},
    );
    await _pumpScene(tester, game, const ValueKey('interior_2_5d'));

    await expectLater(
      find.byKey(const ValueKey('interior_2_5d')),
      matchesGoldenFile('goldens/interior_scene_2_5d.png'),
    );
  });
}

Future<void> _pumpScene(
  WidgetTester tester,
  FlameGame game,
  Key repaintKey,
) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: repaintKey,
        child: GameWidget(game: game),
      ),
    ),
  );
  for (var frame = 0; frame < 100 && !game.isLoaded; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 12)),
    );
  }
  expect(game.isLoaded, isTrue, reason: 'The 2.5D scene must finish loading.');
  await tester.pump(const Duration(milliseconds: 160));
}
