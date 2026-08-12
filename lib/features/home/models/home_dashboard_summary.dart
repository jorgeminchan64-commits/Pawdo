class RelationshipSummary {
  const RelationshipSummary({
    required this.durationLabel,
    required this.nextMomentLabel,
    required this.totalDays,
    required this.nextAnniversary,
  });

  final String durationLabel;
  final String nextMomentLabel;
  final int totalDays;
  final DateTime? nextAnniversary;
}

String greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'Buenos días';
  if (hour >= 12 && hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String formatDashboardClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

RelationshipSummary relationshipSummary(DateTime? start, DateTime now) {
  if (start == null) {
    return const RelationshipSummary(
      durationLabel: 'Su historia empieza aquí',
      nextMomentLabel: 'Configuren su fecha de relación en Perfil',
      totalDays: 0,
      nextAnniversary: null,
    );
  }

  final firstDay = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  if (firstDay.isAfter(today)) {
    return const RelationshipSummary(
      durationLabel: 'Su historia empieza pronto',
      nextMomentLabel: 'Revisa la fecha de relación en Perfil',
      totalDays: 0,
      nextAnniversary: null,
    );
  }

  var years = today.year - firstDay.year;
  var cursor = _addYears(firstDay, years);
  if (cursor.isAfter(today)) {
    years--;
    cursor = _addYears(firstDay, years);
  }

  var months = 0;
  while (months < 11) {
    final candidate = _addMonths(cursor, 1);
    if (candidate.isAfter(today)) break;
    cursor = candidate;
    months++;
  }
  final days = today.difference(cursor).inDays;

  final parts = <String>[
    if (years > 0) '$years ${years == 1 ? 'año' : 'años'}',
    if (months > 0) '$months ${months == 1 ? 'mes' : 'meses'}',
    if (days > 0 || (years == 0 && months == 0))
      '$days ${days == 1 ? 'día' : 'días'}',
  ];

  var nextAnniversary = _addYears(firstDay, today.year - firstDay.year);
  if (nextAnniversary.isBefore(today)) {
    nextAnniversary = _addYears(firstDay, today.year - firstDay.year + 1);
  }
  final daysUntil = nextAnniversary.difference(today).inDays;
  final nextMoment = daysUntil == 0
      ? '¡Su aniversario es hoy! ❤️'
      : 'Próximo aniversario en $daysUntil ${daysUntil == 1 ? 'día' : 'días'}';

  return RelationshipSummary(
    durationLabel: '${parts.join(', ')} juntos ❤️',
    nextMomentLabel: nextMoment,
    totalDays: today.difference(firstDay).inDays,
    nextAnniversary: nextAnniversary,
  );
}

DateTime _addYears(DateTime value, int years) {
  final targetYear = value.year + years;
  final day = _clampDay(targetYear, value.month, value.day);
  return DateTime(targetYear, value.month, day);
}

DateTime _addMonths(DateTime value, int months) {
  final absoluteMonth = value.year * 12 + value.month - 1 + months;
  final year = absoluteMonth ~/ 12;
  final month = absoluteMonth % 12 + 1;
  final day = _clampDay(year, month, value.day);
  return DateTime(year, month, day);
}

int _clampDay(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return day > lastDay ? lastDay : day;
}
