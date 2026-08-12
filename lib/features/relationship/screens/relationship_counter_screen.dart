import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../home/models/home_dashboard_summary.dart';
import '../services/relationship_service.dart';

class RelationshipCounterScreen extends StatefulWidget {
  const RelationshipCounterScreen({super.key, required this.coupleCode});
  final String coupleCode;

  @override
  State<RelationshipCounterScreen> createState() =>
      _RelationshipCounterScreenState();
}

class _RelationshipCounterScreenState extends State<RelationshipCounterScreen> {
  final RelationshipService _service = RelationshipService();
  bool _saving = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nuestra historia')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleCode)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() ?? const <String, dynamic>{};
        final stamp = data['relationshipStartDate'];
        final start = stamp is Timestamp ? stamp.toDate() : null;
        final summary = relationshipSummary(start, DateTime.now());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE75A8C), Color(0xFF743B83)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    summary.durationLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    start == null
                        ? 'Elijan juntos el primer día'
                        : '${summary.totalDays} días compartidos',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Detail(
              icon: Icons.calendar_today_rounded,
              title: 'Fecha de inicio',
              value: start == null ? 'Sin configurar' : _date(start),
            ),
            _Detail(
              icon: Icons.celebration_rounded,
              title: 'Próximo aniversario',
              value: summary.nextAnniversary == null
                  ? 'Aún no calculado'
                  : '${_date(summary.nextAnniversary!)} · ${summary.nextMomentLabel}',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : () => _pick(start),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(start == null ? 'Elegir fecha' : 'Corregir fecha'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta fecha es compartida: cualquier cambio se verá en las dos cuentas.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );

  Future<void> _pick(DateTime? current) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Guardar fecha compartida?'),
        content: Text(
          'Ambos verán ${_date(selected)} como inicio de la relación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.setStartDate(widget.coupleCode, selected);
    } on RelationshipException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
