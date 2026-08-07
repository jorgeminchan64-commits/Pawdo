import 'dart:async';

import 'package:flutter/material.dart';

import '../models/offline_memory_game.dart';

class OfflineMemoryScreen extends StatefulWidget {
  const OfflineMemoryScreen({super.key, this.game});

  final OfflineMemoryGame? game;

  @override
  State<OfflineMemoryScreen> createState() => _OfflineMemoryScreenState();
}

class _OfflineMemoryScreenState extends State<OfflineMemoryScreen>
    with WidgetsBindingObserver {
  late final OfflineMemoryGame _game = widget.game ?? OfflineMemoryGame();
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _flip(int index) {
    final result = _game.flip(index);
    if (result == OfflineMemoryTurn.ignored) return;
    setState(() {});
    if (result == OfflineMemoryTurn.mismatch) {
      _scheduleMismatchResolution();
    }
  }

  void _scheduleMismatchResolution() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 900), () {
      _hideTimer = null;
      if (!mounted || !_game.locked) return;
      setState(_game.resolveMismatch);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_game.locked) _scheduleMismatchResolution();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  void _reset() {
    _hideTimer?.cancel();
    _hideTimer = null;
    setState(_game.reset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        foregroundColor: Colors.purple,
        elevation: 0,
        title: const Text('Memoria offline'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            'Modo offline · sin internet · sin recompensas ni sincronización pendiente.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Movimientos: ${_game.moves}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '${_game.matched.length ~/ 2}/8 parejas',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (_game.complete) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '¡Completaste el tablero!',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 350;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: compact ? 7 : 10,
                      crossAxisSpacing: compact ? 7 : 10,
                    ),
                    itemCount: _game.cards.length,
                    itemBuilder: (context, index) {
                      final visible = _game.isVisible(index);
                      return Semantics(
                        button: true,
                        label: visible
                            ? 'Carta ${_game.cards[index]}'
                            : 'Carta oculta ${index + 1}',
                        child: InkWell(
                          key: ValueKey('offline_memory_card_$index'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: !_game.locked && !visible && !_game.complete
                              ? () => _flip(index)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              color: visible
                                  ? Colors.white
                                  : const Color(0xFF9C55C7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.purple.shade100,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                visible ? _game.cards[index] : '?',
                                style: TextStyle(
                                  fontSize: compact ? 23 : 29,
                                  color: visible ? null : Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Barajar de nuevo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
