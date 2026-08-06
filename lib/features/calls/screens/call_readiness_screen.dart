import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/call_readiness_service.dart';

class CallReadinessScreen extends StatefulWidget {
  const CallReadinessScreen({super.key});

  @override
  State<CallReadinessScreen> createState() => _CallReadinessScreenState();
}

class _CallReadinessScreenState extends State<CallReadinessScreen> {
  final CallReadinessService _service = CallReadinessService();
  late Future<CallCapabilities> _capabilities = _service.capabilities();
  bool _requesting = false;
  bool _probingMicrophone = false;
  bool _probingCamera = false;
  bool? _microphonePassed;
  bool? _cameraPassed;
  double? _microphoneLevel;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      final result = await _service.requestPermissions();
      if (mounted) setState(() => _capabilities = Future.value(result));
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'No se pudieron comprobar los permisos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _probeMicrophone() async {
    setState(() => _probingMicrophone = true);
    try {
      final result = await _service.probeMicrophone();
      if (!mounted) return;
      setState(() {
        _microphonePassed = result.success;
        _microphoneLevel = result.level;
      });
    } on PlatformException catch (error) {
      if (mounted) _showProbeError(error);
    } finally {
      if (mounted) setState(() => _probingMicrophone = false);
    }
  }

  Future<void> _probeCamera() async {
    setState(() => _probingCamera = true);
    try {
      final result = await _service.probeCamera();
      if (!mounted) return;
      setState(() => _cameraPassed = result.success);
    } on PlatformException catch (error) {
      if (mounted) _showProbeError(error);
    } finally {
      if (mounted) setState(() => _probingCamera = false);
    }
  }

  void _showProbeError(PlatformException error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message ?? 'No se pudo completar la prueba.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3FF),
        title: const Text('Prueba técnica de llamadas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Card(
            color: Color(0xFFFFF0D7),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esto no inicia ni simula una llamada. Solo comprueba hardware y permisos antes de elegir y configurar un proveedor seguro.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<CallCapabilities>(
            future: _capabilities,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('No se pudo consultar el hardware.'),
                        TextButton(
                          onPressed: () => setState(
                            () => _capabilities = _service.capabilities(),
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final value = snapshot.data!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _CapabilityRow(
                        icon: Icons.mic_none,
                        label: 'Micrófono disponible',
                        ready: value.microphoneAvailable,
                      ),
                      _CapabilityRow(
                        icon: Icons.videocam_outlined,
                        label: 'Cámara disponible',
                        ready: value.cameraAvailable,
                      ),
                      _CapabilityRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Permiso de micrófono',
                        ready: value.microphonePermission,
                      ),
                      _CapabilityRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Permiso de cámara',
                        ready: value.cameraPermission,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _requesting ? null : _request,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(_requesting ? 'Comprobando…' : 'Probar permisos ahora'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _HardwareProbeCard(
            probingMicrophone: _probingMicrophone,
            probingCamera: _probingCamera,
            microphonePassed: _microphonePassed,
            cameraPassed: _cameraPassed,
            microphoneLevel: _microphoneLevel,
            onMicrophone: _probeMicrophone,
            onCamera: _probeCamera,
          ),
          const SizedBox(height: 16),
          const _ArchitectureCard(),
          const SizedBox(height: 16),
          const _DataSaverCard(),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Privacidad: nada se ejecuta automáticamente. Las pruebas locales activan brevemente el indicador de privacidad de Android, pero no crean archivos, no guardan muestras y no envían audio ni video a Internet.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HardwareProbeCard extends StatelessWidget {
  const _HardwareProbeCard({
    required this.probingMicrophone,
    required this.probingCamera,
    required this.microphonePassed,
    required this.cameraPassed,
    required this.microphoneLevel,
    required this.onMicrophone,
    required this.onCamera,
  });

  final bool probingMicrophone;
  final bool probingCamera;
  final bool? microphonePassed;
  final bool? cameraPassed;
  final double? microphoneLevel;
  final VoidCallback onMicrophone;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prueba local aislada',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Primero concede los permisos. Después puedes verificar cada dispositivo por separado.',
              ),
              const SizedBox(height: 14),
              _ProbeButton(
                icon: Icons.mic_none,
                label: probingMicrophone
                    ? 'Escuchando durante 1 segundo…'
                    : 'Probar micrófono durante 1 segundo',
                result: microphonePassed,
                onPressed: probingMicrophone || probingCamera
                    ? null
                    : onMicrophone,
              ),
              if (microphonePassed == true && microphoneLevel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(
                    value: (microphoneLevel! * 12)
                        .clamp(0.04, 1.0)
                        .toDouble(),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              const SizedBox(height: 10),
              _ProbeButton(
                icon: Icons.videocam_outlined,
                label: probingCamera
                    ? 'Comprobando cámara…'
                    : 'Abrir y cerrar cámara sin capturar',
                result: cameraPassed,
                onPressed: probingCamera || probingMicrophone ? null : onCamera,
              ),
              const SizedBox(height: 10),
              const Text(
                'El micrófono se procesa solo en memoria y la cámara no toma fotografías ni crea video.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
}

class _ProbeButton extends StatelessWidget {
  const _ProbeButton({
    required this.icon,
    required this.label,
    required this.result,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool? result;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            result == true
                ? Icons.check_circle
                : result == false
                    ? Icons.error_outline
                    : icon,
            color: result == true ? Colors.green : null,
          ),
          label: Text(result == true ? '$label · correcto' : label),
        ),
      );
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.icon, required this.label, required this.ready});
  final IconData icon;
  final String label;
  final bool ready;
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: Icon(
          ready ? Icons.check_circle : Icons.cancel_outlined,
          color: ready ? Colors.green : Colors.grey,
        ),
      );
}

class _ArchitectureCard extends StatelessWidget {
  const _ArchitectureCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recomendación para el MVP',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('• Proveedor administrado basado en WebRTC: LiveKit Cloud.'),
              Text('• Tokens de sala emitidos únicamente por Cloud Functions.'),
              Text('• Una sala privada por pareja y llamada.'),
              Text('• TURN, reconexión y métricas administradas.'),
              Text('• Sin grabación habilitada por defecto.'),
              Text('• Migración futura posible al servidor LiveKit abierto.'),
              SizedBox(height: 8),
              Text(
                'No se integra todavía porque requiere crear una cuenta/proyecto externo, aceptar costos y custodiar credenciales del proveedor.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _DataSaverCard extends StatelessWidget {
  const _DataSaverCard();
  @override
  Widget build(BuildContext context) => const Card(
        color: Color(0xFFE5F0FF),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Perfil previsto de ahorro de datos',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('• Iniciar video en 360p y 15 FPS.'),
              Text('• Usar capas adaptativas y pausar video no visible.'),
              Text('• Bajar automáticamente a audio cuando empeore la red.'),
              Text('• Cámara siempre apagada al ir a segundo plano.'),
              Text('• Botones de silencio, cámara y cambio de cámara locales.'),
            ],
          ),
        ),
      );
}
