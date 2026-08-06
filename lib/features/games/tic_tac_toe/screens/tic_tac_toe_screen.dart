import 'package:flutter/material.dart';

import '../../widgets/mini_game_host.dart';

class TicTacToeScreen extends StatelessWidget {
  const TicTacToeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'tic_tac_toe',
      builder: (context, data, uid, busy, play) {
        final board = List<String>.from(
          data['board'] as List? ?? List.filled(9, ''),
        );
        final turnUid = data['turnUid']?.toString() ?? '';
        final winnerUid = data['winnerUid']?.toString() ?? '';
        final phase = data['phase']?.toString() ?? 'playing';
        final symbol = data['symbols'] is Map
            ? (data['symbols'][uid]?.toString() ?? '')
            : '';
        final myTurn = turnUid == uid && phase == 'playing';
        final status = phase == 'complete'
            ? winnerUid.isEmpty
                  ? 'Empate: una gran partida'
                  : winnerUid == uid
                  ? '¡Ganaste esta ronda!'
                  : 'Tu pareja ganó esta ronda'
            : myTurn
            ? 'Tu turno · juegas con $symbol'
            : 'Esperando la jugada de tu pareja';
        return PawdoGameScaffold(
          title: 'Tres en raya ⭕',
          subtitle: status,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  GamePanel(
                    child: SizedBox(
                      width: 320,
                      height: 320,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: 9,
                        itemBuilder: (context, index) => InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: busy || !myTurn || board[index].isNotEmpty
                              ? null
                              : () => play('move', {'index': index}),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDF7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                board[index],
                                style: TextStyle(
                                  fontSize: 55,
                                  fontWeight: FontWeight.w900,
                                  color: board[index] == 'X'
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
                  const SizedBox(height: 18),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OnlineGameControls(
                    data: data,
                    currentUid: uid,
                    busy: busy,
                    play: play,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
