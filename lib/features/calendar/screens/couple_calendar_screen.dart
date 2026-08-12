import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../memories/screens/memory_album_screen.dart';
import '../models/couple_event.dart';
import '../services/couple_calendar_service.dart';

class CoupleCalendarScreen extends StatefulWidget {
  const CoupleCalendarScreen({super.key});

  @override
  State<CoupleCalendarScreen> createState() => _CoupleCalendarScreenState();
}

class _CoupleCalendarScreenState extends State<CoupleCalendarScreen> {
  final CoupleCalendarService _service = CoupleCalendarService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  int _view = 0;

  Future<void> _add(String code) async {
    final data = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventForm(initialDate: _selected),
    );
    if (data == null || !mounted) return;
    try {
      await _service.create(
        coupleCode: code,
        title: data.title,
        description: data.description,
        date: data.date,
        category: data.category,
        emoji: data.emoji,
        reminderMinutes: data.reminderMinutes,
        addPhoto: data.addPhoto,
      );
    } on CalendarException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, profile) {
        final code = profile.data?.data()?['coupleCode']?.toString() ?? '';
        if (code.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Conecta a tu pareja para usar el calendario.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Calendario de pareja')),
          floatingActionButton: _view == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _add(code),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Evento'),
                ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Mes'),
                      icon: Icon(Icons.calendar_month_rounded),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Próximos'),
                      icon: Icon(Icons.upcoming_rounded),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Recuerdos'),
                      icon: Icon(Icons.photo_album_rounded),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
              ),
              Expanded(
                child: _view == 2
                    ? _MemoriesLink(
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MemoryAlbumScreen(),
                          ),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _service.watch(code),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('No se pudo cargar el calendario.'),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final events = snapshot.data!.docs
                              .map(CoupleEvent.fromDocument)
                              .toList();
                          return _view == 0
                              ? _MonthView(
                                  month: _month,
                                  selected: _selected,
                                  events: events,
                                  onMonth: (value) =>
                                      setState(() => _month = value),
                                  onDay: (value) =>
                                      setState(() => _selected = value),
                                  service: _service,
                                  coupleCode: code,
                                  uid: uid,
                                )
                              : _EventList(
                                  events: CoupleCalendarService.upcoming(
                                    events,
                                    DateTime.now(),
                                  ),
                                  service: _service,
                                  coupleCode: code,
                                  uid: uid,
                                );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selected,
    required this.events,
    required this.onMonth,
    required this.onDay,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final DateTime month;
  final DateTime selected;
  final List<CoupleEvent> events;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;
  final CoupleCalendarService service;
  final String coupleCode;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final selectedEvents = events
        .where((event) => event.occursOn(selected))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(month.month)} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final value in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(child: Text(value, textAlign: TextAlign.center)),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: offset + days,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, index - offset + 1);
            final count = events.where((event) => event.occursOn(day)).length;
            final active =
                day.year == selected.year &&
                day.month == selected.month &&
                day.day == selected.day;
            return InkWell(
              onTap: () => onDay(day),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: active ? Colors.pink.shade100 : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : null,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.pink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(height: 28),
        Text(
          'Eventos del ${_shortDate(selected)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (selectedEvents.isEmpty) const Text('No hay eventos para este día.'),
        ...selectedEvents.map(
          (event) => _EventCard(
            event: event,
            service: service,
            coupleCode: coupleCode,
            uid: uid,
          ),
        ),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final List<CoupleEvent> events;
  final CoupleCalendarService service;
  final String coupleCode;
  final String uid;
  @override
  Widget build(BuildContext context) => events.isEmpty
      ? const Center(child: Text('No hay próximos eventos.'))
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
          itemCount: events.length,
          itemBuilder: (_, index) => _EventCard(
            event: events[index],
            service: service,
            coupleCode: coupleCode,
            uid: uid,
          ),
        );
}

class _MemoriesLink extends StatelessWidget {
  const _MemoriesLink({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_album_rounded, size: 54),
              const SizedBox(height: 12),
              const Text(
                'Revive sus momentos especiales en el álbum compartido.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir recuerdos'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.service,
    required this.coupleCode,
    required this.uid,
  });
  final CoupleEvent event;
  final CoupleCalendarService service;
  final String coupleCode;
  final String uid;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Text(event.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(
        event.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${event.categoryLabel} · ${_shortDate(event.date)} ${_clock(event.date)}${event.description.isEmpty ? '' : '\n${event.description}'}',
      ),
      isThreeLine: event.description.isNotEmpty,
      trailing: event.createdBy == uid
          ? IconButton(
              tooltip: 'Eliminar evento',
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline_rounded),
            )
          : null,
      onTap: event.photoPath == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: FutureBuilder<Uint8List>(
                  future: service.loadPhoto(event.photoPath!),
                  builder: (_, snapshot) => snapshot.hasData
                      ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                      : const SizedBox(
                          height: 240,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              ),
            ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar evento?'),
        content: Text('“${event.title}” se quitará del calendario compartido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.delete(coupleCode: coupleCode, eventId: event.id);
    } on CalendarException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _EventDraft {
  const _EventDraft({
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.emoji,
    required this.reminderMinutes,
    required this.addPhoto,
  });
  final String title;
  final String description;
  final DateTime date;
  final CoupleEventCategory category;
  final String emoji;
  final int? reminderMinutes;
  final bool addPhoto;
}

class _EventForm extends StatefulWidget {
  const _EventForm({required this.initialDate});
  final DateTime initialDate;
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late DateTime _date = widget.initialDate;
  CoupleEventCategory _category = CoupleEventCategory.date;
  String _emoji = '💗';
  int? _reminder;
  bool _photo = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nuevo evento', style: Theme.of(context).textTheme.titleLarge),
            TextField(
              controller: _title,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _description,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            DropdownButtonFormField<CoupleEventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: CoupleEventCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_categoryLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            DropdownButtonFormField<String>(
              initialValue: _emoji,
              decoration: const InputDecoration(labelText: 'Emoji'),
              items: const ['💗', '🎉', '✈️', '🎂', '📅', '🌟', '💬']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _emoji = value ?? _emoji),
            ),
            DropdownButtonFormField<int?>(
              initialValue: _reminder,
              decoration: const InputDecoration(labelText: 'Recordatorio'),
              items: CoupleCalendarService.reminderOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_reminderLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _reminder = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora'),
              subtitle: Text('${_shortDate(_date)} ${_clock(_date)}'),
              onTap: _pickDateTime,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _photo,
              title: const Text('Agregar foto opcional'),
              onChanged: (value) => setState(() => _photo = value),
            ),
            FilledButton(
              onPressed: _title.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      _EventDraft(
                        title: _title.text.trim(),
                        description: _description.text.trim(),
                        date: _date,
                        category: _category,
                        emoji: _emoji,
                        reminderMinutes: _reminder,
                        addPhoto: _photo,
                      ),
                    ),
              child: const Text('Guardar evento'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDateTime() async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _date,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null) {
      setState(
        () => _date = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }
}

String _categoryLabel(CoupleEventCategory value) => CoupleEvent(
  id: '',
  title: '',
  description: '',
  date: DateTime(2026),
  category: value,
  emoji: '',
  reminderMinutes: null,
  createdBy: '',
  photoPath: null,
).categoryLabel;
String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _monthName(int month) => const [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
][month - 1];
String _reminderLabel(int? value) => switch (value) {
  null => 'Sin recordatorio',
  0 => 'Al comenzar',
  30 => '30 minutos antes',
  60 => '1 hora antes',
  1440 => '1 día antes',
  10080 => '1 semana antes',
  _ => '$value minutos antes',
};
