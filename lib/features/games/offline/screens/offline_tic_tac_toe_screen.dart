import 'package:flutter/material.dart';

import '../models/offline_tic_tac_toe_game.dart';

class OfflineTicTacToeScreen extends StatefulWidget {
  const OfflineTicTacToeScreen({super.key});

  @override
  State<OfflineTicTacToeScreen> createState() => _OfflineTicTacToeScreenState();
}

class _OfflineTicTacToeScreenState extends State<OfflineTicTacToeScreen> {
  final OfflineTicTacToeGame _game = OfflineTicTacToeGame();

  String get _status => switch (_game.outcome) {
    OfflineTicTacToeOutcome.playing => 'Tu turno: elige una casilla',
    OfflineTicTacToeOutcome.userWon => '¡Ganaste a Pawdo!',
    OfflineTicTacToeOutcome.pawdoWon => 'Pawdo ganó esta ronda',
    OfflineTicTacToeOutcome.draw => 'Empate: gran partida',
  };

  void _play(int index) {
    if (_game.playUser(index)) setState(() {});
  }

  void _reset() => setState(_game.reset);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        foregroundColor: Colors.purple,
        elevation: 0,
        title: const Text('Tres en raya offline'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = (constraints.maxWidth - 40).clamp(240.0, 360.0);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _OfflineBanner(),
                const SizedBox(height: 18),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: 9,
                      itemBuilder: (context, index) => Semantics(
                        button: true,
                        label: _game.board[index].isEmpty
                            ? 'Casilla ${index + 1} vacía'
                            : 'Casilla ${index + 1}: ${_game.board[index]}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap:
                              _game.outcome ==
                                      OfflineTicTacToeOutcome.playing &&
                                  _game.board[index].isEmpty
                              ? () => _play(index)
                              : null,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withValues(alpha: 0.10),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _game.board[index],
                                style: TextStyle(
                                  fontSize: side / 6,
                                  fontWeight: FontWeight.w900,
                                  color: _game.board[index] == 'X'
                                      ? Colors.purple
                                      : Colors.pink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tú juegas con X. Pawdo intentará ganar y bloquear tus jugadas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nueva partida'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8B7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.brown),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo offline · funciona sin internet · no entrega ni sincroniza recompensas.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
