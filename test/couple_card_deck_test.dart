import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/games/lightweight/models/couple_card_deck.dart';

void main() {
  test('every lightweight mode has varied bounded cards', () {
    for (final mode in CoupleCardMode.values) {
      final deck = CoupleCardDeck(mode, seed: 4);
      expect(deck.cards.length, greaterThanOrEqualTo(6));
      expect(deck.cards.every((card) => card.options.length == 2), isTrue);
      expect(deck.cards.every((card) => card.prompt.trim().isNotEmpty), isTrue);
    }
  });

  test('deck avoids repeating the same card consecutively', () {
    final deck = CoupleCardDeck(CoupleCardMode.chooseOne, seed: 8);
    var previous = deck.next();
    for (var index = 0; index < 30; index++) {
      final current = deck.next();
      expect(current.prompt, isNot(previous.prompt));
      previous = current;
    }
  });
}
