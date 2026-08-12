import 'package:flutter/material.dart';

import '../models/wellness_models.dart';
import '../services/wellness_service.dart';

class WellnessPrivacyScreen extends StatefulWidget {
  const WellnessPrivacyScreen({super.key, required this.settings});
  final WellnessSettings settings;

  @override
  State<WellnessPrivacyScreen> createState() => _WellnessPrivacyScreenState();
}

class _WellnessPrivacyScreenState extends State<WellnessPrivacyScreen> {
  final WellnessService _service = WellnessService();
  late int _cycleLength;
  late int _periodLength;
  late bool _regularCycle;
  late bool _reminders;
  late bool _sharing;
  late Set<String> _fields;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cycleLength = widget.settings.cycleLength;
    _periodLength = widget.settings.periodLength;
    _regularCycle = widget.settings.regularCycle;
    _reminders = widget.settings.remindersEnabled;
    _sharing = widget.settings.sharingEnabled;
    _fields = {...widget.settings.sharedFields};
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveSettings(
        cycleLength: _cycleLength,
        periodLength: _periodLength,
        regularCycle: _regularCycle,
        remindersEnabled: _reminders,
        sharingEnabled: _sharing,
        sharedFields: _sharing ? _fields : const {},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacidad actualizada.')),
        );
      }
    } on WellnessException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSharing(bool value) async {
    if (!value) {
      setState(() {
        _sharing = false;
        _fields.clear();
      });
      await _save();
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consentimiento para compartir'),
        content: const Text(
          'Tu pareja solo verá los campos que elijas. El historial, las fechas del periodo y las notas seguirán privados. Puedes retirar el permiso inmediatamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entiendo y acepto'),
          ),
        ],
      ),
    );
    if (accepted == true) setState(() => _sharing = true);
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todos mis datos'),
        content: const Text(
          'Se eliminarán historial, notas, configuración y cualquier resumen compartido. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.deleteAllData();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on WellnessException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad de bienestar'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFEDE6F7),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 34),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privado por defecto. Tu pareja no puede abrir tu historial ni leer tus notas.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Regular')),
              ButtonSegment(value: false, label: Text('Irregular')),
            ],
            selected: {_regularCycle},
            onSelectionChanged: (value) =>
                setState(() => _regularCycle = value.first),
          ),
          const SizedBox(height: 6),
          Text(
            _regularCycle
                ? 'Pawdo mostrará una fecha orientativa.'
                : 'Pawdo mostrará un rango aproximado, nunca un diagnóstico.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _cycleLength,
            decoration: const InputDecoration(
              labelText: 'Duración habitual del ciclo',
            ),
            items: [
              for (var day = 21; day <= 45; day++)
                DropdownMenuItem(value: day, child: Text('$day días')),
            ],
            onChanged: (value) =>
                setState(() => _cycleLength = value ?? _cycleLength),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _periodLength,
            decoration: const InputDecoration(
              labelText: 'Duración habitual del periodo',
            ),
            items: [
              for (var day = 2; day <= 10; day++)
                DropdownMenuItem(value: day, child: Text('$day días')),
            ],
            onChanged: (value) =>
                setState(() => _periodLength = value ?? _periodLength),
          ),
          SwitchListTile(
            value: _reminders,
            title: const Text('Recordatorio privado'),
            subtitle: const Text(
              'Mostrar la próxima estimación dentro del módulo.',
            ),
            onChanged: (value) => setState(() => _reminders = value),
          ),
          const Divider(height: 28),
          SwitchListTile(
            value: _sharing,
            title: const Text('Compartir apoyo con mi pareja'),
            subtitle: const Text(
              'Requiere consentimiento explícito y revocable.',
            ),
            onChanged: _saving ? null : _toggleSharing,
          ),
          if (_sharing) ...[
            CheckboxListTile(
              value: _fields.contains('mood'),
              title: const Text('Estado de ánimo'),
              onChanged: (value) => setState(
                () => value == true
                    ? _fields.add('mood')
                    : _fields.remove('mood'),
              ),
            ),
            CheckboxListTile(
              value: _fields.contains('intensity'),
              title: const Text('Intensidad del día'),
              onChanged: (value) => setState(
                () => value == true
                    ? _fields.add('intensity')
                    : _fields.remove('intensity'),
              ),
            ),
            CheckboxListTile(
              value: _fields.contains('symptoms'),
              title: const Text('Síntomas seleccionados'),
              onChanged: (value) => setState(
                () => value == true
                    ? _fields.add('symptoms')
                    : _fields.remove('symptoms'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Las notas y las fechas exactas nunca se comparten.'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando…' : 'Guardar configuración'),
          ),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _saving ? null : _deleteAll,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar todos mis datos de bienestar'),
          ),
        ],
      ),
    );
  }
}
