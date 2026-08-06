import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_sharing_service.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  final LocationSharingService _service = LocationSharingService();
  late final Future<String> _coupleCode = _service.requireCoupleCode();
  bool _busy = false;
  String? _resumedSession;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final selection = await showModalBottomSheet<_LocationSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ShareOptions(),
    );
    if (selection == null || !mounted) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar ubicación compartida'),
        content: Text(
          'Tu pareja podrá ver tu ubicación ${selection.approximate ? 'aproximada' : 'precisa'} durante ${_modeLabel(selection.mode).toLowerCase()}. '
          'Puedes detenerla inmediatamente. Pawdo solo actualizará mientras la aplicación esté abierta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compartir ahora'),
          ),
        ],
      ),
    );
    if (consent != true) return;
    setState(() => _busy = true);
    try {
      await _service.start(
        mode: selection.mode,
        approximate: selection.approximate,
      );
    } on LocationSharingException catch (error) {
      if (mounted) await _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await _service.stop();
      _resumedSession = null;
    } on LocationSharingException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(LocationSharingException error) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No se pudo obtener ubicación'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
          if (error.settingsRequired)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir ajustes'),
            ),
        ],
      ),
    );
    if (openSettings == true) {
      if (error.locationSettingsRequired) {
        await _service.openLocationSettings();
      } else {
        await _service.openAppSettings();
      }
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  Future<void> _openMap(LocationShare share) async {
    if (!share.hasPosition) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${share.latitude},${share.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _message('No se encontró una aplicación de mapas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F8FF),
        title: const Text('Ubicación temporal'),
      ),
      body: FutureBuilder<String>(
        future: _coupleCode,
        builder: (context, codeSnapshot) {
          if (codeSnapshot.hasError) {
            return Center(child: Text(codeSnapshot.error.toString()));
          }
          final code = codeSnapshot.data;
          if (code == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<LocationShare>>(
            stream: _service.watchShares(code),
            builder: (context, snapshot) {
              final shares = snapshot.data ?? const <LocationShare>[];
              LocationShare? mine;
              LocationShare? partner;
              for (final share in shares) {
                if (share.expired) continue;
                if (share.ownerUid == _service.currentUid) {
                  mine = share;
                } else {
                  partner = share;
                }
              }
              if (mine != null &&
                  mine.active &&
                  _resumedSession != mine.sessionId) {
                _resumedSession = mine.sessionId;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _service.resume(mine!).catchError((_) {});
                });
              }
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const _PrivacyNotice(),
                  const SizedBox(height: 14),
                  if (mine != null)
                    _OwnShareCard(share: mine, busy: _busy, onStop: _stop)
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        _busy ? 'Preparando…' : 'Compartir mi ubicación',
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Tu pareja',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (partner == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Tu pareja no está compartiendo ubicación.',
                        ),
                      ),
                    )
                  else
                    _PartnerShareCard(
                      share: partner,
                      onMap: () => _openMap(partner!),
                    ),
                  const SizedBox(height: 18),
                  const Card(
                    color: Color(0xFFFFF2D8),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Pawdo no guarda un historial de recorridos. Solo existe el último punto de cada persona y se elimina al detener, vencer o desvincularse.',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ShareOptions extends StatefulWidget {
  const _ShareOptions();
  @override
  State<_ShareOptions> createState() => _ShareOptionsState();
}

class _ShareOptionsState extends State<_ShareOptions> {
  String _mode = '15m';
  bool _approximate = true;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo quieres compartir',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Duración'),
            items: const [
              DropdownMenuItem(
                value: 'point',
                child: Text('Ubicación puntual'),
              ),
              DropdownMenuItem(value: '15m', child: Text('Durante 15 minutos')),
              DropdownMenuItem(value: '1h', child: Text('Durante 1 hora')),
              DropdownMenuItem(value: '8h', child: Text('Durante 8 horas')),
              DropdownMenuItem(
                value: 'until_stopped',
                child: Text('Hasta que yo la detenga'),
              ),
            ],
            onChanged: (value) => setState(() => _mode = value ?? _mode),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _approximate,
            title: const Text('Usar ubicación aproximada'),
            subtitle: const Text(
              'Recomendado: el servidor reduce la precisión antes de compartir.',
            ),
            onChanged: (value) => setState(() => _approximate = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _LocationSelection(mode: _mode, approximate: _approximate),
              ),
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationSelection {
  const _LocationSelection({required this.mode, required this.approximate});
  final String mode;
  final bool approximate;
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFDDEBFF),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFF315D9C)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Nunca se activa sola. Android pedirá permiso únicamente después de que confirmes. Las actualizaciones son solo en primer plano.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _OwnShareCard extends StatelessWidget {
  const _OwnShareCard({
    required this.share,
    required this.busy,
    required this.onStop,
  });
  final LocationShare share;
  final bool busy;
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFDFF5E8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF267B52)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  share.active
                      ? 'Estás compartiendo'
                      : 'Ubicación puntual enviada',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_modeLabel(share.mode)} · ${share.approximate ? 'Aproximada' : 'Precisa'}',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Detener y eliminar ahora'),
          ),
        ],
      ),
    ),
  );
}

class _PartnerShareCard extends StatelessWidget {
  const _PartnerShareCard({required this.share, required this.onMap});
  final LocationShare share;
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            share.approximate
                ? 'Ubicación aproximada compartida'
                : 'Ubicación precisa compartida',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            share.updatedAt == null
                ? 'Esperando el primer punto…'
                : 'Actualizada ${_age(share.updatedAt!)}',
          ),
          if (share.accuracyMeters != null)
            Text('Precisión aproximada: ${share.accuracyMeters!.round()} m'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: share.hasPosition ? onMap : null,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir en mapas'),
          ),
        ],
      ),
    ),
  );
}

String _modeLabel(String mode) => switch (mode) {
  'point' => 'Ubicación puntual',
  '15m' => '15 minutos',
  '1h' => '1 hora',
  '8h' => '8 horas',
  'until_stopped' => 'Hasta detener',
  _ => 'Temporal',
};

String _age(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'ahora';
  if (difference.inHours < 1) return 'hace ${difference.inMinutes} min';
  return 'hace ${difference.inHours} h';
}
