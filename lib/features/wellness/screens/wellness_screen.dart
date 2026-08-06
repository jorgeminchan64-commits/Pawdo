import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/wellness_models.dart';
import '../services/wellness_service.dart';
import 'wellness_entry_screen.dart';
import 'wellness_privacy_screen.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final WellnessService _service = WellnessService();
  late final Future<Stream<DocumentSnapshot<Map<String, dynamic>>>?>
  _partnerSummary = _service.partnerSummary();
  bool _activating = false;

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      await _service.saveSettings(
        cycleLength: 28,
        periodLength: 5,
        remindersEnabled: false,
        sharingEnabled: false,
        sharedFields: const {},
      );
    } on WellnessException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  Future<void> _deleteEntry(WellnessEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este registro?'),
        content: const Text('Se borrará de tu historial privado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteEntry(entry.dateKey);
    } on WellnessException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WellnessSettings>(
      stream: _service.watchSettings(),
      builder: (context, settingsSnapshot) {
        final settings =
            settingsSnapshot.data ??
            const WellnessSettings(
              enabled: false,
              cycleLength: 28,
              periodLength: 5,
              remindersEnabled: false,
              sharingEnabled: false,
              sharedFields: {},
            );
        return Scaffold(
          backgroundColor: const Color(0xFFFFF5F8),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFF5F8),
            foregroundColor: const Color(0xFF8D345E),
            title: const Text('Ciclo y bienestar'),
            actions: [
              if (settings.enabled)
                IconButton(
                  tooltip: 'Privacidad y configuración',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WellnessPrivacyScreen(settings: settings),
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined),
                ),
            ],
          ),
          body: !settings.enabled
              ? _OptIn(
                  activating: _activating,
                  onActivate: _activate,
                  partnerSummary: _partnerSummary,
                )
              : StreamBuilder<List<WellnessEntry>>(
                  stream: _service.watchEntries(),
                  builder: (context, entriesSnapshot) {
                    if (!entriesSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final entries = entriesSnapshot.data!;
                    final insights = CycleInsights.fromEntries(
                      entries,
                      settings,
                    );
                    return Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            _InsightCard(
                              insights: insights,
                              settings: settings,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WellnessEntryScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Registrar cómo me siento hoy'),
                            ),
                            const SizedBox(height: 18),
                            _PartnerSupport(summary: _partnerSummary),
                            const SizedBox(height: 20),
                            Text(
                              'Historial privado',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            if (entries.isEmpty)
                              const _EmptyHistory()
                            else
                              ...entries.map(
                                (entry) => _EntryCard(
                                  entry: entry,
                                  onEdit: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          WellnessEntryScreen(entry: entry),
                                    ),
                                  ),
                                  onDelete: () => _deleteEntry(entry),
                                ),
                              ),
                            const SizedBox(height: 16),
                            const _MedicalNotice(),
                          ],
                        ),
                        if (entriesSnapshot.hasData &&
                            entriesSnapshot.connectionState ==
                                ConnectionState.waiting)
                          const LinearProgressIndicator(minHeight: 2),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _OptIn extends StatelessWidget {
  const _OptIn({
    required this.activating,
    required this.onActivate,
    required this.partnerSummary,
  });
  final bool activating;
  final VoidCallback onActivate;
  final Future<Stream<DocumentSnapshot<Map<String, dynamic>>>?> partnerSummary;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Icon(Icons.favorite_outline, size: 72, color: Color(0xFFB34F78)),
      const SizedBox(height: 18),
      const Text(
        'Un espacio opcional y privado',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      const Text(
        'Registra periodo, intensidad, síntomas, ánimo y notas. Todo empieza privado: tu pareja no puede ver nada salvo que después elijas campos específicos.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.45),
      ),
      const SizedBox(height: 18),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tus controles',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text('• Consentimiento explícito y revocable.'),
              Text('• Las notas nunca se comparten.'),
              Text(
                '• Protegido por Firebase; aún no usa cifrado de extremo a extremo.',
              ),
              Text('• Eliminación completa disponible.'),
              Text('• Sin publicidad ni seguimiento oculto.'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const _MedicalNotice(),
      const SizedBox(height: 14),
      _PartnerSupport(summary: partnerSummary),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: activating ? null : onActivate,
        child: Text(activating ? 'Activando…' : 'Activar módulo privado'),
      ),
    ],
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insights, required this.settings});
  final CycleInsights insights;
  final WellnessSettings settings;

  @override
  Widget build(BuildContext context) {
    final estimate = insights.nextPeriodEstimate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFDCE8), Color(0xFFEBDCF7)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insights.phaseLabel,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (insights.hasData) ...[
            const SizedBox(height: 8),
            Text('Día orientativo ${insights.cycleDay} del ciclo'),
            if (estimate != null)
              Text(
                'Próximo periodo estimado: ${_friendlyDate(estimate)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 8),
            Text(
              insights.recordedCycles < 3
                  ? 'Estimación inicial: mejora al registrar más ciclos.'
                  : 'Calculado con ${insights.recordedCycles} inicios registrados.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (settings.remindersEnabled && estimate != null) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.notifications_none, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Recordatorio privado activo dentro de Pawdo.'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final WellnessEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onEdit,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE2EC),
        child: Text('${entry.date.day}'),
      ),
      title: Text(
        '${_friendlyDate(entry.date)} · ${wellnessMoodLabels[entry.mood] ?? entry.mood}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          wellnessFlowLabels[entry.flow] ?? entry.flow,
          if (entry.symptoms.isNotEmpty)
            entry.symptoms
                .map((item) => wellnessSymptomLabels[item] ?? item)
                .join(', '),
          if (entry.notes.isNotEmpty) 'Nota privada guardada',
        ].join(' · '),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    ),
  );
}

class _PartnerSupport extends StatelessWidget {
  const _PartnerSupport({required this.summary});
  final Future<Stream<DocumentSnapshot<Map<String, dynamic>>>?> summary;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: summary,
    builder: (context, future) {
      final stream = future.data;
      if (stream == null) return const SizedBox.shrink();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) return const SizedBox.shrink();
          final mood = data['mood']?.toString();
          final intensity = data['intensity']?.toString();
          final symptoms = List<String>.from(
            data['symptoms'] as List? ?? const [],
          );
          final detail = <String>[
            if (mood != null) wellnessMoodLabels[mood] ?? mood,
            if (intensity != null) wellnessFlowLabels[intensity] ?? intensity,
            ...symptoms.map((item) => wellnessSymptomLabels[item] ?? item),
          ];
          return Card(
            color: const Color(0xFFF1E8FA),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apoya a tu pareja',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Estos datos fueron compartidos voluntariamente contigo.',
                  ),
                  if (detail.isNotEmpty) Text(detail.join(' · ')),
                  const SizedBox(height: 6),
                  const Text(
                    'Pregunta cómo se siente y ofrece descanso o compañía.',
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text('Aún no hay registros. Empieza cuando tú quieras.'),
    ),
  );
}

class _MedicalNotice extends StatelessWidget {
  const _MedicalNotice();
  @override
  Widget build(BuildContext context) => const Card(
    color: Color(0xFFFFF1D8),
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Las fechas son estimaciones orientativas. Pawdo no diagnostica, no confirma fertilidad, embarazo u ovulación y no sustituye consejo médico.',
        style: TextStyle(fontSize: 12, height: 1.35),
      ),
    ),
  );
}

String _friendlyDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
