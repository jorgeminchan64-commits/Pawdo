import 'package:flutter/material.dart';

import '../../../core/services/android_widget_service.dart';

class WidgetPrivacyScreen extends StatefulWidget {
  const WidgetPrivacyScreen({super.key});

  @override
  State<WidgetPrivacyScreen> createState() => _WidgetPrivacyScreenState();
}

class _WidgetPrivacyScreenState extends State<WidgetPrivacyScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await AndroidWidgetService.instance.preferences();
    if (!mounted) return;
    setState(() {
      _enabled = preferences.enabled;
      _showContent = preferences.showContent;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AndroidWidgetService.instance.setPreferences(
        enabled: _enabled,
        showContent: _showContent,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacidad del widget actualizada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget de Android')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE2ED), Color(0xFFE9DDF7)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pawdo está esperando 🐾',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Energía 70% · Racha 4 días'),
                      SizedBox(height: 8),
                      Text('Vista previa del primer widget de texto y estado.',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  value: _enabled,
                  title: const Text('Actualizar el widget'),
                  subtitle: const Text(
                    'Usa el último estado cacheado cuando abres Pawdo; no consulta Firestore continuamente.',
                  ),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                SwitchListTile(
                  value: _showContent,
                  title: const Text('Mostrar estado en el widget'),
                  subtitle: const Text(
                    'Desactivado por defecto. Si se oculta, solo aparece un aviso genérico.',
                  ),
                  onChanged: !_enabled
                      ? null
                      : (value) => setState(() => _showContent = value),
                ),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'El widget no incluye datos del ciclo, notas, fotografías ni mensajes. Está disponible solo para la pantalla principal de Android.',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar privacidad'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para añadirlo: mantén pulsada la pantalla principal del teléfono, abre Widgets y selecciona Pawdo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}
