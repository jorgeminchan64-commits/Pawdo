import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/network_recovery_service.dart';
import '../game_snapshot.dart';
import '../services/mini_game_service.dart';

typedef MiniGameAction =
    Future<Map<String, dynamic>> Function(
      String action, [
      Map<String, dynamic>? payload,
    ]);

typedef MiniGameBuilder =
    Widget Function(
      BuildContext context,
      Map<String, dynamic> data,
      String currentUid,
      bool busy,
      MiniGameAction play,
    );

class MiniGameHost extends StatefulWidget {
  const MiniGameHost({super.key, required this.gameId, required this.builder});

  final String gameId;
  final MiniGameBuilder builder;

  @override
  State<MiniGameHost> createState() => _MiniGameHostState();
}

class _MiniGameHostState extends State<MiniGameHost> {
  final MiniGameService _service = MiniGameService();
  late final VoidCallback _unregisterRecovery;
  String? _coupleCode;
  String? _error;
  bool _busy = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _unregisterRecovery = NetworkRecoveryService.instance.registerRecoveryTask(
      'mini_game_${widget.gameId}_${identityHashCode(this)}',
      _recoverRoom,
    );
    _open();
  }

  @override
  void dispose() {
    _unregisterRecovery();
    super.dispose();
  }

  Future<void> _recoverRoom() async {
    final coupleCode = _coupleCode ?? await _service.requireCoupleCode();
    await _service.openGame(coupleCode, widget.gameId);
    if (!mounted) return;
    setState(() {
      _coupleCode = coupleCode;
      _error = null;
    });
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await _recoverRoom();
    } on MiniGameException catch (error) {
      if (mounted) setState(() => _error = error.message);
      if (error.retryable) {
        NetworkRecoveryService.instance.reportTransientFailure();
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<Map<String, dynamic>> _play(
    String action, [
    Map<String, dynamic>? payload,
  ]) async {
    final coupleCode = _coupleCode;
    if (coupleCode == null || _busy) return const {};
    setState(() => _busy = true);
    try {
      return await _service.play(
        coupleCode: coupleCode,
        gameId: widget.gameId,
        action: action,
        payload: payload ?? const <String, dynamic>{},
      );
    } on MiniGameException catch (error) {
      if (error.retryable) {
        NetworkRecoveryService.instance.reportTransientFailure();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return const {};
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _coupleCode == null) {
      return PawdoGameScaffold(
        title: 'Juegos Pawdo',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 44, color: Colors.purple),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _opening ? null : _open,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final coupleCode = _coupleCode;
    if (coupleCode == null) {
      return const PawdoGameScaffold(
        title: 'Juegos Pawdo',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.watchGame(coupleCode, widget.gameId),
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return PawdoGameScaffold(
            title: 'Juegos Pawdo',
            child: Center(
              child: FilledButton.icon(
                onPressed: _opening ? null : _open,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconectar'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const PawdoGameScaffold(
            title: 'Juegos Pawdo',
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() ?? const <String, dynamic>{};
        final joinedBy = GameSnapshot.strings(data['joinedBy']);
        if (joinedBy.length < 2) {
          return PawdoGameScaffold(
            title: 'Sala de pareja',
            subtitle: 'Sala online segura',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: GamePanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        size: 50,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Esperando a tu pareja',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La partida comenzará cuando abra este mismo juego en su teléfono.',
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: _opening ? null : _open,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar conexión'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final game = widget.builder(
          context,
          data,
          _service.currentUid,
          _busy,
          _play,
        );
        final fromCache = snapshot.data!.metadata.isFromCache;
        return Stack(
          children: [
            IgnorePointer(ignoring: fromCache, child: game),
            if (fromCache)
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
                      'Sin conexión · viendo la última partida guardada. Las jugadas están pausadas.',
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
  }
}

class PawdoGameScaffold extends StatelessWidget {
  const PawdoGameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        foregroundColor: Colors.purple,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child,
        ),
      ),
    );
  }
}

class GamePanel extends StatelessWidget {
  const GamePanel({super.key, required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class OnlineGameControls extends StatelessWidget {
  const OnlineGameControls({
    super.key,
    required this.data,
    required this.currentUid,
    required this.busy,
    required this.play,
  });

  final Map<String, dynamic> data;
  final String currentUid;
  final bool busy;
  final MiniGameAction play;

  @override
  Widget build(BuildContext context) {
    final complete = data['phase'] == 'complete';
    final votes = GameSnapshot.strings(data['restartRequestedBy']);
    final alreadyRequested = votes.contains(currentUid);
    if (complete) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: busy || alreadyRequested
                ? null
                : () => play('request_restart'),
            icon: const Icon(Icons.refresh),
            label: Text(
              alreadyRequested
                  ? 'Esperando aprobación de tu pareja'
                  : 'Solicitar revancha',
            ),
          ),
          if (votes.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'La nueva ronda comienza cuando ambos la aprueben.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    }
    return TextButton.icon(
      onPressed: busy
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Abandonar la partida?'),
                  content: const Text(
                    'La ronda terminará sin recompensa. Esta acción no se puede deshacer.',
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
              if (confirmed == true) await play('abandon');
            },
      icon: const Icon(Icons.flag_outlined),
      label: const Text('Abandonar ronda'),
    );
  }
}
