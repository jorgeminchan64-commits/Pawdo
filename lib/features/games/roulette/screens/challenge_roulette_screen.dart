import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_snapshot.dart';
import '../../widgets/mini_game_host.dart';

class ChallengeRouletteScreen extends StatefulWidget {
  const ChallengeRouletteScreen({super.key});

  @override
  State<ChallengeRouletteScreen> createState() =>
      _ChallengeRouletteScreenState();
}

class _ChallengeRouletteScreenState extends State<ChallengeRouletteScreen> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'challenge_roulette',
      builder: (context, data, uid, busy, play) {
        final challenge =
            data['challenge']?.toString() ?? 'Gira para descubrir un reto';
        final confirmations = GameSnapshot.strings(data['confirmedBy']);
        final completed = data['phase'] == 'complete';
        final confirmed = confirmations.contains(uid);
        return PawdoGameScaffold(
          title: 'Ruleta de retos 🎡',
          subtitle: 'Retos bonitos y seguros para compartir',
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: AnimatedRotation(
                  turns: _turns,
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.pink,
                          Colors.purple,
                          Colors.orange,
                          Colors.pink,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'PAWDO\n💗',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              GamePanel(
                child: Text(
                  challenge,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!completed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(
                                  () =>
                                      _turns += 4 + math.Random().nextDouble(),
                                );
                                await play('spin');
                              },
                        icon: const Icon(Icons.casino),
                        label: const Text('Girar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy || confirmed
                            ? null
                            : () => play('confirm'),
                        icon: Icon(confirmed ? Icons.check : Icons.favorite),
                        label: Text(confirmed ? 'Confirmado' : 'Reto cumplido'),
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: busy ? null : () => play('next'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nuevo reto'),
                ),
              const SizedBox(height: 10),
              Text(
                '${confirmations.length}/2 confirmaciones',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
