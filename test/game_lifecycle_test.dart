import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/games/catch_pawdo/screens/catch_pawdo_screen.dart';
import 'package:pawdo/features/games/offline/models/offline_memory_game.dart';
import 'package:pawdo/features/games/offline/screens/offline_memory_screen.dart';

void main() {
  testWidgets('Catch Pawdo pauses its countdown in background', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CatchPawdoScreen()));
    await tester.tap(find.text('Jugar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('⏱ 18 s'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('⏱ 18 s'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('⏱ 17 s'), findsOneWidget);
  });

  testWidgets('Memory defers mismatch resolution while backgrounded', (
    tester,
  ) async {
    final game = OfflineMemoryGame(random: Random(9));
    final first = 0;
    final second = game.cards.indexWhere((card) => card != game.cards[first]);
    await tester.pumpWidget(MaterialApp(home: OfflineMemoryScreen(game: game)));

    await tester.tap(find.byKey(ValueKey('offline_memory_card_$first')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('offline_memory_card_$second')));
    await tester.pump();
    expect(game.locked, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(game.locked, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 900));
    expect(game.locked, isFalse);
  });
}
