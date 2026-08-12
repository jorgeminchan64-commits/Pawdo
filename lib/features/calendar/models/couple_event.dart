import 'package:cloud_firestore/cloud_firestore.dart';

enum CoupleEventCategory {
  anniversary,
  date,
  outing,
  travel,
  birthday,
  special,
  memory,
  conversation,
  reminder,
}

class CoupleEvent {
  const CoupleEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.emoji,
    required this.reminderMinutes,
    required this.createdBy,
    required this.photoPath,
  });

  factory CoupleEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CoupleEvent(
      id: document.id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(1970),
      category: CoupleEventCategory.values.firstWhere(
        (value) => value.name == data['category'],
        orElse: () => CoupleEventCategory.special,
      ),
      emoji: data['emoji']?.toString() ?? '💗',
      reminderMinutes: (data['reminderMinutes'] as num?)?.toInt(),
      createdBy: data['createdBy']?.toString() ?? '',
      photoPath: data['photoPath']?.toString(),
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final CoupleEventCategory category;
  final String emoji;
  final int? reminderMinutes;
  final String createdBy;
  final String? photoPath;

  String get categoryLabel => switch (category) {
    CoupleEventCategory.anniversary => 'Aniversario',
    CoupleEventCategory.date => 'Cita',
    CoupleEventCategory.outing => 'Salida',
    CoupleEventCategory.travel => 'Viaje',
    CoupleEventCategory.birthday => 'Cumpleaños',
    CoupleEventCategory.special => 'Día especial',
    CoupleEventCategory.memory => 'Recuerdo',
    CoupleEventCategory.conversation => 'Situación relevante',
    CoupleEventCategory.reminder => 'Recordatorio',
  };

  bool occursOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;
}
