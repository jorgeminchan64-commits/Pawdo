import 'package:flutter/material.dart';

import '../../widgets/mini_game_host.dart';

class CoupleMemoryScreen extends StatelessWidget {
  const CoupleMemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniGameHost(
      gameId: 'couple_memory',
      builder: (context, data, uid, busy, play) {
        final cards = List<dynamic>.from(
          data['cards'] as List? ?? List.filled(16, ''),
        );
        final revealed = List<int>.from(
          (data['revealed'] as List? ?? const []).map(
            (e) => (e as num).toInt(),
          ),
        );
        final matched = List<int>.from(
          (data['matched'] as List? ?? const []).map((e) => (e as num).toInt()),
        );
        final turnUid = data['turnUid']?.toString() ?? '';
        final phase = data['phase']?.toString() ?? 'playing';
        final myTurn = turnUid == uid;
        final complete = phase == 'complete';
        return PawdoGameScaffold(
          title: 'Memoria de pareja 🧠',
          subtitle: complete
              ? '¡Encontraron todas las parejas!'
              : myTurn
              ? 'Tu turno'
              : 'Turno de tu pareja',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Movimientos: ${data['moves'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${matched.length ~/ 2}/8 parejas',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    final visible =
                        matched.contains(index) || revealed.contains(index);
                    return Semantics(
                      button: true,
                      label: visible
                          ? 'Carta ${cards[index]}'
                          : 'Carta oculta ${index + 1}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap:
                            busy ||
                                complete ||
                                !myTurn ||
                                visible ||
                                phase == 'resolve'
                            ? null
                            : () => play('flip', {'index': index}),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: visible
                                ? Colors.white
                                : const Color(0xFFB45AD8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: visible
                                  ? Colors.pink.shade100
                                  : Colors.purple.shade200,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.12),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              visible ? cards[index].toString() : '?',
                              style: TextStyle(
                                fontSize: visible ? 30 : 26,
                                color: visible ? null : Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: phase == 'resolve'
                    ? FilledButton.icon(
                        onPressed: busy ? null : () => play('continue'),
                        icon: const Icon(Icons.visibility_off),
                        label: const Text('Ocultar y continuar'),
                      )
                    : complete
                    ? OnlineGameControls(
                        data: data,
                        currentUid: uid,
                        busy: busy,
                        play: play,
                      )
                    : Column(
                        children: [
                          Text(
                            myTurn
                                ? 'Elige dos cartas'
                                : 'Las cartas se sincronizan en tiempo real',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          OnlineGameControls(
                            data: data,
                            currentUid: uid,
                            busy: busy,
                            play: play,
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
