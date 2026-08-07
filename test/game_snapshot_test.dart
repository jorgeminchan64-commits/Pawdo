import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/games/game_snapshot.dart';

void main() {
  group('GameSnapshot', () {
    test('pads and sanitizes fixed remote boards', () {
      final board = GameSnapshot.fixedStrings(
        <dynamic>['X', 7, 'invalid', 'O'],
        length: 9,
        allowed: const {'', 'X', 'O'},
      );

      expect(board, hasLength(9));
      expect(board.take(4), <String>['X', '', '', 'O']);
      expect(board.skip(4), everyElement(isEmpty));
    });

    test('keeps only unique indices inside the board', () {
      expect(
        GameSnapshot.indices(<dynamic>[0, 2.9, 2, -1, 16, '4'], upperBound: 16),
        <int>[0, 2],
      );
    });

    test('ignores malformed string collections', () {
      expect(
        GameSnapshot.strings(<dynamic>['user-a', 4, null, 'user-b']),
        <String>['user-a', 'user-b'],
      );
      expect(GameSnapshot.strings('not-a-list'), isEmpty);
    });
  });
}
