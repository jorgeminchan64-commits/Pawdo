import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/games/offline/models/offline_memory_game.dart';

void main() {
  group('OfflineMemoryGame', () {
    test('creates exactly eight local pairs', () {
      final game = OfflineMemoryGame(random: Random(4));
      final counts = <String, int>{};
      for (final card in game.cards) {
        counts[card] = (counts[card] ?? 0) + 1;
      }
      expect(game.cards, hasLength(16));
      expect(counts, hasLength(8));
      expect(counts.values, everyElement(2));
    });

    test('locks mismatched cards until they are hidden', () {
      final game = OfflineMemoryGame(random: Random(9));
      final first = 0;
      final second = game.cards.indexWhere((card) => card != game.cards[first]);
      expect(game.flip(first), OfflineMemoryTurn.first);
      expect(game.flip(second), OfflineMemoryTurn.mismatch);
      expect(game.locked, isTrue);
      expect(game.flip(3), OfflineMemoryTurn.ignored);
      game.resolveMismatch();
      expect(game.revealed, isEmpty);
      expect(game.locked, isFalse);
    });

    test('matched cards remain visible and count one move', () {
      final game = OfflineMemoryGame(random: Random(12));
      final first = 0;
      final second = game.cards.lastIndexOf(game.cards[first]);
      expect(game.flip(first), OfflineMemoryTurn.first);
      expect(game.flip(second), OfflineMemoryTurn.match);
      expect(game.matched, containsAll([first, second]));
      expect(game.moves, 1);
    });
  });
}
