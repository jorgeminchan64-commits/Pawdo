import 'dart:math';

enum OfflineMemoryTurn { ignored, first, match, mismatch, complete }

class OfflineMemoryGame {
  OfflineMemoryGame({Random? random}) : _random = random ?? Random() {
    reset();
  }

  static const symbols = ['🐾', '💖', '🌸', '⭐', '🦴', '🎀', '🌙', '🍪'];

  final Random _random;
  late List<String> cards;
  final Set<int> matched = <int>{};
  final List<int> revealed = <int>[];
  int moves = 0;
  bool locked = false;

  bool get complete => matched.length == cards.length;
  bool isVisible(int index) =>
      matched.contains(index) || revealed.contains(index);

  OfflineMemoryTurn flip(int index) {
    if (locked || index < 0 || index >= cards.length || isVisible(index)) {
      return OfflineMemoryTurn.ignored;
    }
    revealed.add(index);
    if (revealed.length == 1) return OfflineMemoryTurn.first;

    moves += 1;
    final first = revealed.first;
    if (cards[first] == cards[index]) {
      matched.addAll(revealed);
      revealed.clear();
      return complete ? OfflineMemoryTurn.complete : OfflineMemoryTurn.match;
    }
    locked = true;
    return OfflineMemoryTurn.mismatch;
  }

  void resolveMismatch() {
    revealed.clear();
    locked = false;
  }

  void reset() {
    cards = [...symbols, ...symbols]..shuffle(_random);
    matched.clear();
    revealed.clear();
    moves = 0;
    locked = false;
  }
}
