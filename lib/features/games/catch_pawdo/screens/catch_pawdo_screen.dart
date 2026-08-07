import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class CatchPawdoScreen extends StatefulWidget {
  const CatchPawdoScreen({super.key});

  @override
  State<CatchPawdoScreen> createState() => _CatchPawdoScreenState();
}

class _CatchPawdoScreenState extends State<CatchPawdoScreen>
    with WidgetsBindingObserver {
  final Random _random = Random.secure();
  Timer? _timer;
  int _seconds = 20;
  int _score = 0;
  double _x = .5;
  double _y = .5;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _seconds = 20;
      _score = 0;
      _running = true;
      _move();
    });
    _resumeTimer();
  }

  void _resumeTimer() {
    if (!_running || (_timer?.isActive ?? false)) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_seconds <= 1) {
          _seconds = 0;
          _running = false;
          timer.cancel();
        } else {
          _seconds--;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _move() {
    _x = .05 + _random.nextDouble() * .82;
    _y = .05 + _random.nextDouble() * .78;
  }

  void _catch() {
    if (!_running) return;
    setState(() {
      _score++;
      _move();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        foregroundColor: Colors.purple,
        elevation: 0,
        title: const Text(
          'Atrapa a Pawdo 🐶',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Puntos: $_score',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '⏱ $_seconds s',
                    style: const TextStyle(
                      fontSize: 19,
                      color: Colors.purple,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFDDEC), Color(0xFFE9D8FF)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(
                    children: [
                      if (_running)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 140),
                          left: _x * (constraints.maxWidth - 100),
                          top: _y * (constraints.maxHeight - 100),
                          child: Semantics(
                            button: true,
                            label: 'Atrapar a Pawdo',
                            child: GestureDetector(
                              onTap: _catch,
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    '🐶',
                                    style: TextStyle(fontSize: 46),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _score == 0
                                      ? '¿Qué tan rápido puedes atrapar a Pawdo?'
                                      : '¡Terminaste con $_score puntos!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: _start,
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(
                                    _score == 0 ? 'Jugar' : 'Jugar otra vez',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Modo arcade local: no modifica monedas ni recompensas.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
