import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../services/ludo_service.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LudoService _ludoService = LudoService();

  late final ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final Future<String?> _coupleCodeFuture;

  String? _joinedCoupleCode;
  String? _joinError;
  bool _joining = false;
  bool _actionBusy = false;
  String? _celebratedVictoryKey;

  static const int _finishPosition = 52;
  static const int _boardSize = 15;

  // A = rosado / abajo derecha.
  // B = morado / arriba izquierda.
  static const int _startIndexA = 36;
  static const int _startIndexB = 10;

  final List<math.Point<int>> _trackCells = const [
    math.Point(6, 0),
    math.Point(6, 1),
    math.Point(6, 2),
    math.Point(6, 3),
    math.Point(6, 4),
    math.Point(6, 5),
    math.Point(5, 6),
    math.Point(4, 6),
    math.Point(3, 6),
    math.Point(2, 6),
    math.Point(1, 6),
    math.Point(0, 6),
    math.Point(0, 7),
    math.Point(0, 8),
    math.Point(1, 8),
    math.Point(2, 8),
    math.Point(3, 8),
    math.Point(4, 8),
    math.Point(5, 8),
    math.Point(6, 9),
    math.Point(6, 10),
    math.Point(6, 11),
    math.Point(6, 12),
    math.Point(6, 13),
    math.Point(6, 14),
    math.Point(7, 14),
    math.Point(8, 14),
    math.Point(8, 13),
    math.Point(8, 12),
    math.Point(8, 11),
    math.Point(8, 10),
    math.Point(8, 9),
    math.Point(9, 8),
    math.Point(10, 8),
    math.Point(11, 8),
    math.Point(12, 8),
    math.Point(13, 8),
    math.Point(14, 8),
    math.Point(14, 7),
    math.Point(14, 6),
    math.Point(13, 6),
    math.Point(12, 6),
    math.Point(11, 6),
    math.Point(10, 6),
    math.Point(9, 6),
    math.Point(8, 5),
    math.Point(8, 4),
    math.Point(8, 3),
    math.Point(8, 2),
    math.Point(8, 1),
    math.Point(8, 0),
    math.Point(7, 0),
  ];

  final List<math.Point<int>> _homeA = const [
    // Rosado / abajo derecha: centros reales de los 4 círculos de casa.
    math.Point(10, 10),
    math.Point(12, 10),
    math.Point(10, 12),
    math.Point(12, 12),
  ];

  final List<math.Point<int>> _homeB = const [
    // Morado / arriba izquierda: centros reales de los 4 círculos de casa.
    math.Point(2, 2),
    math.Point(4, 2),
    math.Point(2, 4),
    math.Point(4, 4),
  ];

  final List<math.Point<int>> _goalA = const [
    math.Point(13, 7),
    math.Point(12, 7),
    math.Point(11, 7),
    math.Point(10, 7),
  ];

  final List<math.Point<int>> _goalB = const [
    math.Point(1, 7),
    math.Point(2, 7),
    math.Point(3, 7),
    math.Point(4, 7),
  ];

  @override
  void initState() {
    super.initState();

    _coupleCodeFuture = _getCoupleCode();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath), volume: 0.85);
    } catch (_) {
      // Si falta un audio, el juego sigue funcionando.
    }
  }

  void _showVictoryDialog({
    required String winnerName,
    required String winnerSide,
    required bool rewardAwarded,
  }) {
    if (!mounted) return;

    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD6EA), Color(0xFFEED7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/games/ludo/victory_crown.png',
                  width: 120,
                  height: 120,
                  cacheWidth: 360,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return const Text('👑', style: TextStyle(fontSize: 92));
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  '¡Victoria Pawdo!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$winnerName ganó Ludo Pawdo ${_sideEmoji(winnerSide)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rewardAwarded
                      ? '+80 monedas · +4 amor'
                      : 'La recompensa diaria ya fue recibida',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getCoupleCode() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data()?['coupleCode']?.toString();
  }

  DocumentReference<Map<String, dynamic>> _gameRef(String coupleCode) {
    return _db
        .collection('couples')
        .doc(coupleCode)
        .collection('games')
        .doc('ludo');
  }

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Map<String, String> _stringMap(dynamic raw) {
    final result = <String, String>{};

    if (raw is Map) {
      raw.forEach((key, value) {
        if (value != null) {
          result[key.toString()] = value.toString();
        }
      });
    }

    return result;
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  List<int> _tokenList(dynamic raw) {
    final result = <int>[];

    if (raw is List) {
      for (final item in raw) {
        result.add(_toInt(item, -1));
      }
    }

    while (result.length < 4) {
      result.add(-1);
    }

    return result.take(4).toList();
  }

  Future<void> _ensureJoined(String coupleCode) async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      await _ludoService.join(coupleCode);
      if (mounted) setState(() => _joinedCoupleCode = coupleCode);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _joinError = error.message ?? 'No se pudo entrar a la sala.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _joinError = 'Sin conexión. Reintenta para entrar.');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String? _mySide(Map<String, dynamic> data) {
    final user = _auth.currentUser;
    if (user == null) return null;

    final players = _stringMap(data['players']);

    if (players['A'] == user.uid) return 'A';
    if (players['B'] == user.uid) return 'B';

    return null;
  }

  bool _isLegalMove({required int currentPosition, required int dice}) {
    if (dice <= 0) return false;
    if (currentPosition < 0) return dice == 6;
    if (currentPosition >= _finishPosition) return false;

    return true;
  }

  int _trackIndexForSide(String side, int position) {
    if (position < 0) {
      return side == 'A' ? _startIndexA : _startIndexB;
    }

    final startIndex = side == 'A' ? _startIndexA : _startIndexB;
    return (startIndex + position) % _trackCells.length;
  }

  Future<void> _rollDice(String coupleCode) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    await _playSound('audio/dice_roll.mp3');
    try {
      await _ludoService.rollDice(coupleCode);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'No se pudo lanzar el dado.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _moveToken({
    required String coupleCode,
    required int tokenIndex,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final result = await _ludoService.moveToken(
        coupleCode: coupleCode,
        tokenIndex: tokenIndex,
      );
      if (!mounted) return;
      if (result.moved) {
        await _playSound('audio/ludo_move.mp3');
      }
      if (result.won) {
        await _playSound('audio/ludo_win.mp3');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.rewardAwarded
                  ? 'Ganaste Ludo Pawdo 👑 +80 monedas'
                  : 'Ganaste Ludo Pawdo 👑',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Movimiento rechazado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _resetGame(String coupleCode) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    LudoRestartResult? result;
    try {
      result = await _ludoService.reset(coupleCode);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'No se pudo reiniciar.')),
        );
      }
      if (mounted) setState(() => _actionBusy = false);
      return;
    }

    if (!mounted) return;

    setState(() => _actionBusy = false);

    if (!result.restarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. Falta la aprobación de tu pareja.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nueva partida de Ludo iniciada 🎲')),
    );
  }

  Future<void> _abandonGame(String coupleCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar Ludo?'),
        content: const Text(
          'La partida terminará y no se entregará ninguna recompensa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (confirmed != true || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _ludoService.abandon(coupleCode);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'No se pudo abandonar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showInstructions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cómo jugar Ludo Pawdo',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            Text('• Ambos deben entrar a la sala para comenzar.'),
            Text('• Necesitas sacar 6 para liberar una ficha.'),
            Text('• Sacar 6 te concede otro turno.'),
            Text('• Si caes sobre una ficha rival, vuelve a su casa.'),
            Text('• Gana quien lleve sus cuatro fichas a la meta.'),
            Text('• La revancha comienza solo cuando ambos la aprueban.'),
            SizedBox(height: 10),
            Text(
              'La primera victoria diaria puede entregar +80 monedas y +4 amor.',
            ),
          ],
        ),
      ),
    );
  }

  Color _sideColor(String side) {
    return side == 'A' ? const Color(0xFFFF6AA9) : const Color(0xFF8C63FF);
  }

  String _sideEmoji(String side) {
    return side == 'A' ? '💖' : '💜';
  }

  String _sideTitle(String side) {
    return side == 'A' ? 'Jugador A' : 'Jugador B';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, codeSnapshot) {
        final coupleCode = codeSnapshot.data;

        if (codeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF4FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (coupleCode == null || coupleCode.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF4FA),
            body: Center(
              child: Text(
                'Primero necesitas estar vinculado con tu pareja.',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        if (_joinedCoupleCode != coupleCode && !_joining) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureJoined(coupleCode);
          });
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _gameRef(coupleCode).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();

            if (data == null) {
              if (_joinError != null) {
                return Scaffold(
                  backgroundColor: const Color(0xFFFFF4FA),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_joinError!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _joining
                                ? null
                                : () => _ensureJoined(coupleCode),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const Scaffold(
                backgroundColor: Color(0xFFFFF4FA),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final winnerSide = data['winnerSide']?.toString() ?? '';
            final victoryKey = '${data['round'] ?? 1}_$winnerSide';
            final abandoned =
                (data['abandonedBy']?.toString() ?? '').isNotEmpty;
            if (!abandoned &&
                winnerSide.isNotEmpty &&
                _celebratedVictoryKey != victoryKey) {
              _celebratedVictoryKey = victoryKey;
              final names = _stringMap(data['playerNames']);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _playSound('audio/ludo_win.mp3');
                _showVictoryDialog(
                  winnerName: names[winnerSide] ?? 'Jugador $winnerSide',
                  winnerSide: winnerSide,
                  rewardAwarded: data['rewardGranted'] == true,
                );
              });
            }

            final game = _buildGame(coupleCode: coupleCode, data: data);
            if (!snapshot.data!.metadata.isFromCache) return game;
            return Stack(
              children: [
                IgnorePointer(child: game),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 86,
                  child: Material(
                    color: const Color(0xFFFFE8B7),
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Reconectando · el tablero está guardado y las jugadas están pausadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGame({
    required String coupleCode,
    required Map<String, dynamic> data,
  }) {
    final names = _stringMap(data['playerNames']);
    final tokensMap = _map(data['tokens']);

    final tokensA = _tokenList(tokensMap['A']);
    final tokensB = _tokenList(tokensMap['B']);

    final turnSide = data['turnSide']?.toString() ?? 'A';
    final phase = data['phase']?.toString() ?? 'roll';
    final dice = _toInt(data['dice'], 0);
    final winnerSide = data['winnerSide']?.toString() ?? '';
    final joinedBy = List<String>.from(data['joinedBy'] as List? ?? const []);
    final bothReady = joinedBy.length >= 2;
    final restartRequestedBy = List<String>.from(
      data['restartRequestedBy'] as List? ?? const [],
    );
    final lastMove = data['lastMove']?.toString() ?? 'Ludo Pawdo 🎲';

    final mySide = _mySide(data);
    final myTurn = mySide != null && mySide == turnSide && winnerSide.isEmpty;
    final canRoll = myTurn && phase == 'roll' && bothReady && !_actionBusy;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF4FA),
        elevation: 0,
        title: const Text(
          'Ludo Pawdo 🎲',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Cómo jugar',
            onPressed: _showInstructions,
            icon: const Icon(Icons.help_outline),
          ),
          if (phase == 'finished')
            IconButton(
              tooltip: restartRequestedBy.contains(_auth.currentUser?.uid)
                  ? 'Esperando a tu pareja'
                  : 'Solicitar revancha',
              onPressed:
                  _actionBusy ||
                      restartRequestedBy.contains(_auth.currentUser?.uid)
                  ? null
                  : () => _resetGame(coupleCode),
              icon: const Icon(Icons.refresh, color: Colors.purple),
            )
          else if (phase != 'waiting')
            IconButton(
              tooltip: 'Abandonar partida',
              onPressed: _actionBusy ? null : () => _abandonGame(coupleCode),
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;

                if (isLandscape) {
                  final boardSide = _clampDouble(
                    math
                        .min(
                          constraints.maxHeight - 22,
                          constraints.maxWidth * 0.42,
                        )
                        .toDouble(),
                    215,
                    320,
                  );

                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: boardSide + 12,
                          child: Center(
                            child: _board(
                              coupleCode: coupleCode,
                              tokensA: tokensA,
                              tokensB: tokensB,
                              mySide: mySide,
                              turnSide: turnSide,
                              phase: phase,
                              dice: dice,
                              winnerSide: winnerSide,
                              maxSide: boardSide,
                              compact: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _headerCard(
                                mySide: mySide,
                                turnSide: turnSide,
                                phase: phase,
                                winnerSide: winnerSide,
                                lastMove: lastMove,
                                playerA: names['A'] ?? 'Jugador A',
                                playerB: names['B']?.isNotEmpty == true
                                    ? names['B']!
                                    : 'Esperando pareja...',
                                compact: true,
                              ),
                              const SizedBox(height: 10),
                              _playersRow(
                                names: names,
                                turnSide: turnSide,
                                winnerSide: winnerSide,
                                mySide: mySide,
                              ),
                              const SizedBox(height: 10),
                              _dicePanel(
                                coupleCode: coupleCode,
                                canRoll: canRoll,
                                dice: dice,
                                phase: phase,
                                mySide: mySide,
                                turnSide: turnSide,
                                winnerSide: winnerSide,
                                playerBConnected: bothReady,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final boardSide = _clampDouble(
                  math
                      .min(
                        constraints.maxWidth - 24,
                        constraints.maxHeight * 0.50,
                      )
                      .toDouble(),
                  270,
                  450,
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _headerCard(
                      mySide: mySide,
                      turnSide: turnSide,
                      phase: phase,
                      winnerSide: winnerSide,
                      lastMove: lastMove,
                      playerA: names['A'] ?? 'Jugador A',
                      playerB: names['B']?.isNotEmpty == true
                          ? names['B']!
                          : 'Esperando pareja...',
                    ),
                    const SizedBox(height: 14),
                    _playersRow(
                      names: names,
                      turnSide: turnSide,
                      winnerSide: winnerSide,
                      mySide: mySide,
                    ),
                    const SizedBox(height: 16),
                    _board(
                      coupleCode: coupleCode,
                      tokensA: tokensA,
                      tokensB: tokensB,
                      mySide: mySide,
                      turnSide: turnSide,
                      phase: phase,
                      dice: dice,
                      winnerSide: winnerSide,
                      maxSide: boardSide,
                    ),
                    const SizedBox(height: 16),
                    _dicePanel(
                      coupleCode: coupleCode,
                      canRoll: canRoll,
                      dice: dice,
                      phase: phase,
                      mySide: mySide,
                      turnSide: turnSide,
                      winnerSide: winnerSide,
                      playerBConnected: bothReady,
                    ),
                    const SizedBox(height: 16),
                    _tokensPanel(
                      side: 'A',
                      tokens: tokensA,
                      playerName: names['A'] ?? 'Jugador A',
                    ),
                    const SizedBox(height: 10),
                    _tokensPanel(
                      side: 'B',
                      tokens: tokensB,
                      playerName: names['B']?.isNotEmpty == true
                          ? names['B']!
                          : 'Esperando pareja...',
                    ),
                  ],
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 24,
              gravity: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required String? mySide,
    required String turnSide,
    required String phase,
    required String winnerSide,
    required String lastMove,
    required String playerA,
    required String playerB,
    bool compact = false,
  }) {
    final title = winnerSide.isNotEmpty
        ? '${_sideEmoji(winnerSide)} Ganó ${_sideTitle(winnerSide)}'
        : 'Turno de ${_sideEmoji(turnSide)} ${_sideTitle(turnSide)}';

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD8EC), Color(0xFFEBD8FF)],
        ),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ludo de pareja',
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 17 : 22,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12 : 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tú eres: ${mySide == null ? "Espectador" : "${_sideEmoji(mySide)} ${_sideTitle(mySide)}"}',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 13,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              'A: $playerA\nB: $playerB',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            lastMove,
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11.5 : 14,
            ),
          ),
          if (phase == 'choose' && winnerSide.isEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '✨ Toca una ficha iluminada',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playersRow({
    required Map<String, String> names,
    required String turnSide,
    required String winnerSide,
    required String? mySide,
  }) {
    return Row(
      children: [
        Expanded(
          child: _playerCard(
            side: 'A',
            name: names['A'] ?? 'Jugador A',
            active: turnSide == 'A' && winnerSide.isEmpty,
            me: mySide == 'A',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _playerCard(
            side: 'B',
            name: names['B']?.isNotEmpty == true ? names['B']! : 'Esperando...',
            active: turnSide == 'B' && winnerSide.isEmpty,
            me: mySide == 'B',
          ),
        ),
      ],
    );
  }

  Widget _playerCard({
    required String side,
    required String name,
    required bool active,
    required bool me,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: active ? _sideColor(side).withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? _sideColor(side) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _sideColor(side),
            radius: 18,
            child: Text(_sideEmoji(side), style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me ? '$name (Tú)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active ? 'Turno actual' : 'Esperando',
                  style: TextStyle(
                    color: active ? _sideColor(side) : Colors.grey,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board({
    required String coupleCode,
    required List<int> tokensA,
    required List<int> tokensB,
    required String? mySide,
    required String turnSide,
    required String phase,
    required int dice,
    required String winnerSide,
    required double maxSide,
    bool compact = false,
  }) {
    final framePadding = compact ? 5.0 : 8.0;
    final outerRadius = compact ? 26.0 : 34.0;
    final imageRadius = compact ? 20.0 : 26.0;

    return Center(
      child: SizedBox(
        width: maxSide,
        height: maxSide,
        child: Container(
          padding: EdgeInsets.all(framePadding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF1F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(outerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(imageRadius),
            child: LayoutBuilder(
              builder: (context, boardConstraints) {
                final side = math
                    .min(boardConstraints.maxWidth, boardConstraints.maxHeight)
                    .toDouble();

                // El PNG tiene borde y margen. Este inset centra la lógica 15x15
                // sobre la zona real de casillas, no sobre todo el PNG.
                final gridInset = side * 0.073;
                final gridSide = side - (gridInset * 2);
                final cell = gridSide / _boardSize;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/games/ludo/ludo_board.png',
                        fit: BoxFit.fill,
                        cacheWidth:
                            (side * View.of(context).devicePixelRatio).ceil(),
                        errorBuilder: (_, _, _) {
                          return _fallbackBoardGrid(cell);
                        },
                      ),
                    ),
                    Positioned(
                      left: gridInset,
                      top: gridInset,
                      width: gridSide,
                      height: gridSide,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < tokensA.length; i++)
                            _tokenWidget(
                              coupleCode: coupleCode,
                              side: 'A',
                              tokenIndex: i,
                              position: tokensA[i],
                              cell: cell,
                              mySide: mySide,
                              turnSide: turnSide,
                              phase: phase,
                              dice: dice,
                              winnerSide: winnerSide,
                              compact: compact,
                            ),
                          for (int i = 0; i < tokensB.length; i++)
                            _tokenWidget(
                              coupleCode: coupleCode,
                              side: 'B',
                              tokenIndex: i,
                              position: tokensB[i],
                              cell: cell,
                              mySide: mySide,
                              turnSide: turnSide,
                              phase: phase,
                              dice: dice,
                              winnerSide: winnerSide,
                              compact: compact,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackBoardGrid(double cell) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFFFF7FC), Color(0xFFF5E8FF)],
                radius: 0.95,
              ),
            ),
          ),
        ),
        for (int row = 0; row < _boardSize; row++)
          for (int col = 0; col < _boardSize; col++)
            Positioned(
              left: col * cell,
              top: row * cell,
              width: cell,
              height: cell,
              child: _boardCell(row, col),
            ),
      ],
    );
  }

  Widget _boardCell(int row, int col) {
    final point = math.Point(col, row);

    final isTrack = _trackCells.contains(point);
    final isHomeA = _homeA.contains(point);
    final isHomeB = _homeB.contains(point);
    final isGoalA = _goalA.contains(point);
    final isGoalB = _goalB.contains(point);
    final isCenter = row >= 6 && row <= 8 && col >= 6 && col <= 8;

    Color color = const Color(0xFFFFFAFD);

    if (isTrack) color = const Color(0xFFFFE8F4);
    if (isHomeA) color = const Color(0xFFFFD1E7);
    if (isHomeB) color = const Color(0xFFE5D7FF);
    if (isGoalA) color = const Color(0xFFFF9CC5);
    if (isGoalB) color = const Color(0xFFBFA2FF);
    if (isCenter) color = const Color(0xFFF2E6FF);

    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.10)),
      ),
      child: isCenter
          ? const Center(child: Text('🐾', style: TextStyle(fontSize: 11)))
          : null,
    );
  }

  Widget _tokenWidget({
    required String coupleCode,
    required String side,
    required int tokenIndex,
    required int position,
    required double cell,
    required String? mySide,
    required String turnSide,
    required String phase,
    required int dice,
    required String winnerSide,
    required bool compact,
  }) {
    final point = _cellForToken(
      side: side,
      tokenIndex: tokenIndex,
      position: position,
    );

    final canMove =
        winnerSide.isEmpty &&
        mySide == side &&
        turnSide == side &&
        phase == 'choose' &&
        _isLegalMove(currentPosition: position, dice: dice);

    final inHome = position < 0;
    final inGoal = position >= _finishPosition;

    final offsets = [
      Offset(-cell * 0.08, -cell * 0.08),
      Offset(cell * 0.08, -cell * 0.08),
      Offset(-cell * 0.08, cell * 0.08),
      Offset(cell * 0.08, cell * 0.08),
    ];

    // En casa y meta NO usamos offset, porque cada ficha tiene su círculo.
    // En camino sí usamos un offset pequeño para que dos fichas no se tapen.
    final offset = (inHome || inGoal)
        ? Offset.zero
        : offsets[tokenIndex % offsets.length];

    final tokenSize = inHome
        ? cell * (compact ? 0.88 : 0.98)
        : inGoal
        ? cell * (compact ? 0.76 : 0.84)
        : cell * (compact ? 0.62 : 0.68);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      left: point.x * cell + (cell - tokenSize) / 2 + offset.dx,
      top: point.y * cell + (cell - tokenSize) / 2 + offset.dy,
      width: tokenSize,
      height: tokenSize,
      child: GestureDetector(
        onTap: canMove
            ? () => _moveToken(coupleCode: coupleCode, tokenIndex: tokenIndex)
            : null,
        child: AnimatedScale(
          scale: canMove ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 240),
          child: _premiumToken(
            side: side,
            tokenIndex: tokenIndex,
            position: position,
            canMove: canMove,
            size: tokenSize,
          ),
        ),
      ),
    );
  }

  Widget _premiumToken({
    required String side,
    required int tokenIndex,
    required int position,
    required bool canMove,
    required double size,
  }) {
    final isPink = side == 'A';
    final colors = isPink
        ? const [Color(0xFFFFA7CE), Color(0xFFFF4D95)]
        : const [Color(0xFFC6A7FF), Color(0xFF7C56F8)];

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (canMove)
          Container(
            width: size * 1.25,
            height: size * 1.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.yellow.withValues(alpha: 0.30),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.65),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: canMove ? 3.2 : 2.4),
            boxShadow: [
              BoxShadow(
                color: _sideColor(side).withValues(alpha: 0.40),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),

        Positioned(
          top: size * 0.16,
          left: size * 0.20,
          child: Container(
            width: size * 0.28,
            height: size * 0.16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),

        Container(
          width: size * 0.56,
          height: size * 0.56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),

        Text(
          position >= _finishPosition ? '👑' : '${tokenIndex + 1}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.34,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  math.Point<int> _cellForToken({
    required String side,
    required int tokenIndex,
    required int position,
  }) {
    if (position < 0) {
      return side == 'A' ? _homeA[tokenIndex] : _homeB[tokenIndex];
    }

    if (position >= _finishPosition) {
      return side == 'A' ? _goalA[tokenIndex] : _goalB[tokenIndex];
    }

    final trackIndex = _trackIndexForSide(side, position);
    return _trackCells[trackIndex];
  }

  Widget _diceVisual(int dice, {bool compact = false}) {
    final asset = dice <= 0
        ? 'assets/images/games/ludo/dice_empty.png'
        : 'assets/images/games/ludo/dice_$dice.png';

    final size = compact ? 64.0 : 96.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: RotationTransition(
            turns: Tween<double>(begin: 0.04, end: 0).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(dice),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8E7FF), Color(0xFFFFD6EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 18 : 26),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 7 : 10),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            cacheWidth: compact ? 160 : 256,
            errorBuilder: (_, _, _) {
              return Center(
                child: Text(
                  dice == 0 ? '🎲' : '$dice',
                  style: TextStyle(
                    fontSize: compact ? 28 : 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.purple,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dicePanel({
    required String coupleCode,
    required bool canRoll,
    required int dice,
    required String phase,
    required String? mySide,
    required String turnSide,
    required String winnerSide,
    required bool playerBConnected,
    bool compact = false,
  }) {
    String message;

    if (winnerSide.isNotEmpty) {
      message = '${_sideEmoji(winnerSide)} Ganador: ${_sideTitle(winnerSide)}';
    } else if (phase == 'waiting') {
      message = 'Sala creada. Esperando a que tu pareja entre en su teléfono.';
    } else if (mySide == null) {
      message = 'Sala llena. Estás mirando la partida.';
    } else if (mySide != turnSide) {
      message = 'Espera el turno de tu pareja.';
    } else if (phase == 'roll') {
      message = 'Tu turno: lanza el dado.';
    } else {
      message = 'Toca una ficha iluminada para moverla.';
    }

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEEF8)],
        ),
        borderRadius: BorderRadius.circular(compact ? 22 : 30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _diceVisual(dice, compact: compact),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12 : 14,
            ),
          ),
          if (!playerBConnected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Tu pareja todavía no entra. Puedes probar mientras tanto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.55),
                  fontSize: compact ? 10.5 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: compact ? 44 : 54,
            child: ElevatedButton.icon(
              onPressed: canRoll ? () => _rollDice(coupleCode) : null,
              icon: const Icon(Icons.casino),
              label: const Text(
                'Lanzar dado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokensPanel({
    required String side,
    required List<int> tokens,
    required String playerName,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _sideColor(side),
            child: Text(_sideEmoji(side), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$playerName\n${tokens.map(_tokenStatus).join(" · ")}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tokenStatus(int position) {
    if (position < 0) return 'Casa';
    if (position >= _finishPosition) return 'Meta';

    return '$position/$_finishPosition';
  }
}
