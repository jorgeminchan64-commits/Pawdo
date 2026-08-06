import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/notification_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? get _reference {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications');
  }

  Future<void> _save(Map<String, dynamic> values) async {
    final reference = _reference;
    if (reference == null) return;
    setState(() => _saving = true);
    try {
      await reference.set({
        'chatEnabled': values['chatEnabled'] ?? true,
        'quickMessagesEnabled': values['quickMessagesEnabled'] ?? true,
        'hideSensitiveContent': values['hideSensitiveContent'] ?? true,
        'quietHoursEnabled': values['quietHoursEnabled'] ?? false,
        'quietStartHour': values['quietStartHour'] ?? 22,
        'quietEndHour': values['quietEndHour'] ?? 8,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = _reference;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones y privacidad')),
      body: reference == null
          ? const Center(child: Text('Inicia sesión para continuar.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: reference.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final chatEnabled = data['chatEnabled'] != false;
                final quickEnabled = data['quickMessagesEnabled'] != false;
                final hideContent = data['hideSensitiveContent'] != false;
                final quietEnabled = data['quietHoursEnabled'] == true;
                final start = (data['quietStartHour'] as num?)?.toInt() ?? 22;
                final end = (data['quietEndHour'] as num?)?.toInt() ?? 8;
                final values = <String, dynamic>{
                  'chatEnabled': chatEnabled,
                  'quickMessagesEnabled': quickEnabled,
                  'hideSensitiveContent': hideContent,
                  'quietHoursEnabled': quietEnabled,
                  'quietStartHour': start,
                  'quietEndHour': end,
                };
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permiso de Android',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pawdo solicita el permiso solo cuando tú lo activas.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      final allowed = await NotificationService
                                          .instance
                                          .requestPermissionAndRegister();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            allowed
                                                ? 'Notificaciones activadas.'
                                                : 'Android no concedió el permiso.',
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Activar en este teléfono'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SwitchListTile(
                      value: chatEnabled,
                      title: const Text('Mensajes y fotografías'),
                      subtitle: const Text('Avisar cuando tu pareja escriba.'),
                      onChanged: _saving
                          ? null
                          : (value) => _save({...values, 'chatEnabled': value}),
                    ),
                    SwitchListTile(
                      value: quickEnabled,
                      title: const Text('Mensajes rápidos'),
                      subtitle: const Text('Permitir avisos destacados.'),
                      onChanged: _saving
                          ? null
                          : (value) => _save({
                              ...values,
                              'quickMessagesEnabled': value,
                            }),
                    ),
                    SwitchListTile(
                      value: hideContent,
                      title: const Text('Ocultar contenido sensible'),
                      subtitle: const Text(
                        'La pantalla bloqueada mostrará un aviso genérico.',
                      ),
                      onChanged: _saving
                          ? null
                          : (value) => _save({
                              ...values,
                              'hideSensitiveContent': value,
                            }),
                    ),
                    SwitchListTile(
                      value: quietEnabled,
                      title: const Text('Horario silencioso'),
                      subtitle: Text('Sin avisos de $start:00 a $end:00'),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                _save({...values, 'quietHoursEnabled': value}),
                    ),
                    if (quietEnabled)
                      Row(
                        children: [
                          Expanded(
                            child: _HourField(
                              label: 'Desde',
                              value: start,
                              onChanged: (value) =>
                                  _save({...values, 'quietStartHour': value}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HourField(
                              label: 'Hasta',
                              value: end,
                              onChanged: (value) =>
                                  _save({...values, 'quietEndHour': value}),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Privacidad: los mensajes están protegidos por acceso '
                          'de pareja y Firebase, pero todavía no usan cifrado de '
                          'extremo a extremo. Las vistas previas permanecen ocultas '
                          'de forma predeterminada.',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: List.generate(
      24,
      (hour) => DropdownMenuItem(value: hour, child: Text('$hour:00')),
    ),
    onChanged: (hour) {
      if (hour != null) onChanged(hour);
    },
  );
}
