import 'package:flutter/material.dart';

import '../../widgets/mini_game_host.dart';

class MovieGuessScreen extends StatefulWidget {
  const MovieGuessScreen({super.key});

  @override
  State<MovieGuessScreen> createState() => _MovieGuessScreenState();
}

class _MovieGuessScreenState extends State<MovieGuessScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'movie_guess',
      builder: (context, data, uid, busy, play) {
        final phase = data['phase']?.toString() ?? 'guessing';
        final complete = phase == 'complete';
        return PawdoGameScaffold(
          title: 'Adivina la película 🎬',
          subtitle: 'La respuesta se valida de forma privada en el servidor',
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GamePanel(
                color: const Color(0xFF241A36),
                child: Column(
                  children: [
                    Text(
                      data['emoji']?.toString() ?? '🎬',
                      style: const TextStyle(fontSize: 55),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['clue']?.toString() ?? 'Preparando pista…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Intentos de la pareja: ${data['attempts'] ?? 0}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (!complete)
                GamePanel(
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la película',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final guess = _controller.text.trim();
                                if (guess.isEmpty) return;
                                final result = await play('guess', {
                                  'guess': guess,
                                });
                                if (result['correct'] == true) {
                                  _controller.clear();
                                }
                              },
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Comprobar respuesta'),
                      ),
                    ],
                  ),
                )
              else
                GamePanel(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 50,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '¡Respuesta correcta!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['answer']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: busy ? null : () => play('next'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Siguiente película'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
