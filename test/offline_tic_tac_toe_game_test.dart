import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/games/offline/models/offline_tic_tac_toe_game.dart';

void main() {
  group('OfflineTicTacToeGame', () {
    test('Pawdo takes the center after a corner opening', () {
      final game = OfflineTicTacToeGame();
      expect(game.playUser(0), isTrue);
      expect(game.board[0], 'X');
      expect(game.board[4], 'O');
    });

    test('Pawdo blocks an immediate user win', () {
      final game = OfflineTicTacToeGame();
      game.board
        ..[0] = 'X'
        ..[1] = 'X'
        ..[4] = 'O';
      expect(game.playUser(8), isTrue);
      expect(game.board[2], 'O');
    });

    test('rejects occupied and out-of-range cells', () {
      final game = OfflineTicTacToeGame();
      expect(game.playUser(0), isTrue);
      expect(game.playUser(0), isFalse);
      expect(game.playUser(20), isFalse);
    });

    test('reset restores a clean local match', () {
      final game = OfflineTicTacToeGame()..playUser(0);
      game.reset();
      expect(game.board, everyElement(isEmpty));
      expect(game.outcome, OfflineTicTacToeOutcome.playing);
    });
  });
}
