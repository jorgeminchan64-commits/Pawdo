import 'package:flutter/material.dart';

import '../models/wellness_models.dart';
import '../services/wellness_service.dart';

class WellnessEntryScreen extends StatefulWidget {
  const WellnessEntryScreen({super.key, this.entry});
  final WellnessEntry? entry;

  @override
  State<WellnessEntryScreen> createState() => _WellnessEntryScreenState();
}

class _WellnessEntryScreenState extends State<WellnessEntryScreen> {
  final WellnessService _service = WellnessService();
  late final TextEditingController _notes;
  late DateTime _date;
  late String _mood;
  late String _flow;
  late Set<String> _symptoms;
  late bool _periodStarted;
  late bool _periodEnded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = entry?.date ?? DateTime.now();
    _mood = entry?.mood ?? 'calm';
    _flow = entry?.flow ?? 'none';
    _symptoms = entry?.symptoms.toSet() ?? <String>{};
    _periodStarted = entry?.periodStarted ?? false;
    _periodEnded = entry?.periodEnded ?? false;
    _notes = TextEditingController(text: entry?.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.saveEntry(
        date: _date,
        mood: _mood,
        flow: _flow,
        symptoms: _symptoms,
        notes: _notes.text.trim(),
        periodStarted: _periodStarted,
        periodEnded: _periodEnded,
      );
      if (mounted) Navigator.pop(context);
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
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        title: Text(
          widget.entry == null ? 'Nuevo registro' : 'Editar registro',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Fecha'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _chooseDate,
          ),
          const SizedBox(height: 18),
          Text(
            '¿Cómo te sientes?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mood,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            items: wellnessMoodLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _mood = value ?? _mood),
          ),
          const SizedBox(height: 18),
          Text('Intensidad', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _flow,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            items: wellnessFlowLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _flow = value ?? _flow),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _periodStarted,
                  title: const Text('Este día inició mi periodo'),
                  onChanged: (value) => setState(() {
                    _periodStarted = value;
                    if (value) _periodEnded = false;
                  }),
                ),
                SwitchListTile(
                  value: _periodEnded,
                  title: const Text('Este día terminó mi periodo'),
                  onChanged: (value) => setState(() {
                    _periodEnded = value;
                    if (value) _periodStarted = false;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Síntomas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: wellnessSymptomLabels.entries.map((entry) {
              final selected = _symptoms.contains(entry.key);
              return FilterChip(
                selected: selected,
                label: Text(entry.value),
                onSelected: (value) => setState(() {
                  if (value && _symptoms.length < 8) {
                    _symptoms.add(entry.key);
                  } else if (!value) {
                    _symptoms.remove(entry.key);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Nota privada',
              helperText: 'Las notas nunca se comparten con tu pareja.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.lock_outline),
            label: Text(_saving ? 'Guardando…' : 'Guardar de forma privada'),
          ),
        ],
      ),
    );
  }
}
