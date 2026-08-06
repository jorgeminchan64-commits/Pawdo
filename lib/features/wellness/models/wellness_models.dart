import 'package:cloud_firestore/cloud_firestore.dart';

class WellnessSettings {
  const WellnessSettings({
    required this.enabled,
    required this.cycleLength,
    required this.periodLength,
    required this.remindersEnabled,
    required this.sharingEnabled,
    required this.sharedFields,
  });

  factory WellnessSettings.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return WellnessSettings(
      enabled: map['enabled'] == true,
      cycleLength: (map['cycleLength'] as num?)?.toInt() ?? 28,
      periodLength: (map['periodLength'] as num?)?.toInt() ?? 5,
      remindersEnabled: map['remindersEnabled'] == true,
      sharingEnabled: map['sharingEnabled'] == true,
      sharedFields: Set<String>.from(map['sharedFields'] as List? ?? const []),
    );
  }

  final bool enabled;
  final int cycleLength;
  final int periodLength;
  final bool remindersEnabled;
  final bool sharingEnabled;
  final Set<String> sharedFields;
}

class WellnessEntry {
  const WellnessEntry({
    required this.dateKey,
    required this.mood,
    required this.flow,
    required this.symptoms,
    required this.notes,
    required this.periodStarted,
    required this.periodEnded,
  });

  factory WellnessEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return WellnessEntry(
      dateKey: data['dateKey']?.toString() ?? document.id,
      mood: data['mood']?.toString() ?? 'calm',
      flow: data['flow']?.toString() ?? 'none',
      symptoms: List<String>.from(data['symptoms'] as List? ?? const []),
      notes: data['notes']?.toString() ?? '',
      periodStarted: data['periodStarted'] == true,
      periodEnded: data['periodEnded'] == true,
    );
  }

  final String dateKey;
  final String mood;
  final String flow;
  final List<String> symptoms;
  final String notes;
  final bool periodStarted;
  final bool periodEnded;

  DateTime get date => DateTime.tryParse(dateKey) ?? DateTime.now();
}

class CycleInsights {
  const CycleInsights({
    required this.hasData,
    required this.phaseLabel,
    required this.cycleDay,
    required this.nextPeriodEstimate,
    required this.estimatedCycleLength,
    required this.recordedCycles,
  });

  factory CycleInsights.fromEntries(
    List<WellnessEntry> entries,
    WellnessSettings settings,
  ) {
    final starts = entries
        .where((entry) => entry.periodStarted)
        .map((entry) => DateTime(entry.date.year, entry.date.month, entry.date.day))
        .toList()
      ..sort();
    if (starts.isEmpty) {
      return CycleInsights(
        hasData: false,
        phaseLabel: 'Registra el inicio de tu periodo',
        cycleDay: 0,
        nextPeriodEstimate: null,
        estimatedCycleLength: settings.cycleLength,
        recordedCycles: 0,
      );
    }
    final intervals = <int>[];
    for (var index = 1; index < starts.length; index++) {
      final days = starts[index].difference(starts[index - 1]).inDays;
      if (days >= 21 && days <= 45) intervals.add(days);
    }
    final estimatedLength = intervals.isEmpty
        ? settings.cycleLength
        : (intervals.reduce((a, b) => a + b) / intervals.length).round();
    final today = DateTime.now();
    final day = today.difference(starts.last).inDays + 1;
    final phase = day <= 0
        ? 'Próximo ciclo estimado'
        : day <= settings.periodLength
        ? 'Periodo registrado'
        : day <= estimatedLength ~/ 2
        ? 'Primera mitad del ciclo'
        : day <= estimatedLength
        ? 'Segunda mitad del ciclo'
        : 'El ciclo puede estar variando';
    return CycleInsights(
      hasData: true,
      phaseLabel: phase,
      cycleDay: day.clamp(1, 99).toInt(),
      nextPeriodEstimate: starts.last.add(Duration(days: estimatedLength)),
      estimatedCycleLength: estimatedLength,
      recordedCycles: starts.length,
    );
  }

  final bool hasData;
  final String phaseLabel;
  final int cycleDay;
  final DateTime? nextPeriodEstimate;
  final int estimatedCycleLength;
  final int recordedCycles;
}

const wellnessMoodLabels = <String, String>{
  'calm': 'Tranquila',
  'happy': 'Feliz',
  'sensitive': 'Sensible',
  'tired': 'Cansada',
  'sad': 'Triste',
  'irritable': 'Irritable',
  'anxious': 'Ansiosa',
};

const wellnessFlowLabels = <String, String>{
  'none': 'Sin sangrado',
  'spotting': 'Manchado',
  'light': 'Ligero',
  'medium': 'Medio',
  'heavy': 'Abundante',
};

const wellnessSymptomLabels = <String, String>{
  'cramps': 'Cólicos',
  'headache': 'Dolor de cabeza',
  'bloating': 'Hinchazón',
  'fatigue': 'Fatiga',
  'backache': 'Dolor de espalda',
  'acne': 'Acné',
  'nausea': 'Náuseas',
  'tenderness': 'Sensibilidad',
  'insomnia': 'Insomnio',
  'cravings': 'Antojos',
};
