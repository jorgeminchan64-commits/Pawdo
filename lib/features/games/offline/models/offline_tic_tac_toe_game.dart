enum OfflineTicTacToeOutcome { playing, userWon, pawdoWon, draw }

class OfflineTicTacToeGame {
  OfflineTicTacToeGame() : board = List<String>.filled(9, '');

  final List<String> board;
  OfflineTicTacToeOutcome outcome = OfflineTicTacToeOutcome.playing;

  bool playUser(int index) {
    if (!_canPlay(index)) return false;
    board[index] = 'X';
    _updateOutcome();
    if (outcome == OfflineTicTacToeOutcome.playing) _playPawdo();
    return true;
  }

  void reset() {
    board.fillRange(0, board.length, '');
    outcome = OfflineTicTacToeOutcome.playing;
  }

  bool _canPlay(int index) =>
      outcome == OfflineTicTacToeOutcome.playing &&
      index >= 0 &&
      index < board.length &&
      board[index].isEmpty;

  void _playPawdo() {
    final index =
        _winningMove('O') ??
        _winningMove('X') ??
        (board[4].isEmpty ? 4 : null) ??
        _firstFree(const [0, 2, 6, 8]) ??
        _firstFree(const [1, 3, 5, 7]);
    if (index != null) board[index] = 'O';
    _updateOutcome();
  }

  int? _winningMove(String symbol) {
    for (var index = 0; index < board.length; index++) {
      if (board[index].isNotEmpty) continue;
      board[index] = symbol;
      final wins = _winner() == symbol;
      board[index] = '';
      if (wins) return index;
    }
    return null;
  }

  int? _firstFree(List<int> indexes) {
    for (final index in indexes) {
      if (board[index].isEmpty) return index;
    }
    return null;
  }

  void _updateOutcome() {
    final winner = _winner();
    if (winner == 'X') {
      outcome = OfflineTicTacToeOutcome.userWon;
    } else if (winner == 'O') {
      outcome = OfflineTicTacToeOutcome.pawdoWon;
    } else if (board.every((cell) => cell.isNotEmpty)) {
      outcome = OfflineTicTacToeOutcome.draw;
    }
  }

  String _winner() {
    const lines = <List<int>>[
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      final value = board[line[0]];
      if (value.isNotEmpty &&
          value == board[line[1]] &&
          value == board[line[2]]) {
        return value;
      }
    }
    return '';
  }
}
