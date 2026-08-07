import 'package:flutter/material.dart';

import '../../game_snapshot.dart';
import '../../widgets/mini_game_host.dart';

class CoupleQuestionsScreen extends StatefulWidget {
  const CoupleQuestionsScreen({super.key});

  @override
  State<CoupleQuestionsScreen> createState() => _CoupleQuestionsScreenState();
}

class _CoupleQuestionsScreenState extends State<CoupleQuestionsScreen> {
  final TextEditingController _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'couple_questions',
      builder: (context, data, uid, busy, play) {
        final prompt = data['prompt']?.toString() ?? 'Preparando pregunta…';
        final phase = data['phase']?.toString() ?? 'answering';
        final answeredBy = GameSnapshot.strings(data['answeredBy']);
        final answers = Map<String, dynamic>.from(
          data['answers'] as Map? ?? const {},
        );
        final answered = answeredBy.contains(uid);

        return PawdoGameScaffold(
          title: 'Preguntas de pareja 💞',
          subtitle: 'Respondan por separado y descubran sus respuestas',
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              GamePanel(
                color: const Color(0xFFFFE5F2),
                child: Column(
                  children: [
                    const Text(
                      'Pregunta del momento',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (phase != 'complete')
                GamePanel(
                  child: answered
                      ? const Column(
                          children: [
                            Icon(Icons.favorite, color: Colors.pink, size: 42),
                            SizedBox(height: 10),
                            Text(
                              'Respuesta guardada. Esperando a tu pareja…',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            TextField(
                              controller: _answerController,
                              maxLength: 300,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Tu respuesta',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final text = _answerController.text
                                          .trim();
                                      if (text.isEmpty) return;
                                      final result = await play('answer', {
                                        'text': text,
                                      });
                                      if (result['accepted'] == true) {
                                        _answerController.clear();
                                      }
                                    },
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Guardar en secreto'),
                            ),
                          ],
                        ),
                )
              else ...[
                ...answers.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GamePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key == uid
                                ? 'Tu respuesta'
                                : 'Respuesta de tu pareja',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(fontSize: 17, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                OnlineGameControls(
                  data: data,
                  currentUid: uid,
                  busy: busy,
                  play: play,
                ),
              ],
              if (phase != 'complete') ...[
                const SizedBox(height: 10),
                OnlineGameControls(
                  data: data,
                  currentUid: uid,
                  busy: busy,
                  play: play,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
