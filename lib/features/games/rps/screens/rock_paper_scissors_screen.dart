import 'package:flutter/material.dart';

import '../../widgets/mini_game_host.dart';

class RockPaperScissorsScreen extends StatelessWidget {
  const RockPaperScissorsScreen({super.key});

  static const _choices = <String, String>{
    'rock': '✊',
    'paper': '✋',
    'scissors': '✌️',
  };

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'rock_paper_scissors',
      builder: (context, data, uid, busy, play) {
        final submitted = List<String>.from(
          data['submittedBy'] as List? ?? const [],
        );
        final choices = Map<String, dynamic>.from(
          data['choices'] as Map? ?? const {},
        );
        final phase = data['phase']?.toString() ?? 'choosing';
        final winnerUid = data['winnerUid']?.toString() ?? '';
        final mineSubmitted = submitted.contains(uid);
        String result = 'Elige en secreto';
        if (phase == 'complete') {
          result = winnerUid.isEmpty
              ? '¡Empate!'
              : winnerUid == uid
              ? '¡Ganaste!'
              : 'Esta ronda es de tu pareja';
        } else if (mineSubmitted) {
          result = 'Elección guardada. Esperando a tu pareja…';
        }
        return PawdoGameScaffold(
          title: 'Piedra, papel o tijera ✊',
          subtitle: 'Las elecciones permanecen secretas hasta el resultado',
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GamePanel(
                color: const Color(0xFFFFE8F4),
                child: Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (phase != 'complete')
                Row(
                  children: _choices.entries
                      .map(
                        (entry) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: FilledButton(
                              onPressed: busy || mineSubmitted
                                  ? null
                                  : () => play('choose', {'choice': entry.key}),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 22,
                                ),
                              ),
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              else ...[
                ...choices.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GamePanel(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key == uid ? 'Tú' : 'Tu pareja',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _choices[entry.value.toString()] ?? '?',
                            style: const TextStyle(fontSize: 38),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : () => play('next'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Otra ronda'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
