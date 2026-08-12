enum PetMood { happy, sad, tired, hungry, excited, sleeping, dirty }

class PetState {
  const PetState({
    required this.name,
    required this.hunger,
    required this.happiness,
    required this.energy,
    required this.hygiene,
    required this.toiletNeed,
    required this.isSleeping,
    required this.lastAction,
  });

  factory PetState.fromMap(Map<String, dynamic>? data) {
    final value = data ?? const <String, dynamic>{};
    return PetState(
      name: _safeName(value['name']),
      hunger: _stat(value['hunger'], 70),
      happiness: _stat(value['happiness'], 80),
      energy: _stat(value['energy'], 65),
      hygiene: _stat(value['hygiene'], 85),
      toiletNeed: _stat(value['toiletNeed'], 15),
      isSleeping: value['isSleeping'] == true,
      lastAction: value['lastAction']?.toString() ?? 'idle',
    );
  }

  final String name;
  final int hunger;
  final int happiness;
  final int energy;
  final int hygiene;
  final int toiletNeed;
  final bool isSleeping;
  final String lastAction;

  PetMood get mood {
    if (isSleeping) return PetMood.sleeping;
    if (hygiene <= 25 || toiletNeed >= 85) return PetMood.dirty;
    if (hunger <= 25) return PetMood.hungry;
    if (energy <= 20) return PetMood.tired;
    if (happiness <= 30) return PetMood.sad;
    if (happiness >= 88 && energy >= 65) return PetMood.excited;
    return PetMood.happy;
  }

  String get moodLabel => switch (mood) {
    PetMood.happy => 'Feliz',
    PetMood.sad => 'Triste',
    PetMood.tired => 'Cansado',
    PetMood.hungry => 'Hambriento',
    PetMood.excited => 'Emocionado',
    PetMood.sleeping => 'Dormido',
    PetMood.dirty => 'Necesita aseo',
  };

  String get reaction => switch (mood) {
    PetMood.happy => 'Estoy feliz de verlos juntos 🐾',
    PetMood.sad => 'Necesito un poco de cariño.',
    PetMood.tired => 'Tengo sueño… ¿descansamos?',
    PetMood.hungry => 'Mi pancita tiene hambre.',
    PetMood.excited => '¡Quiero jugar con ustedes!',
    PetMood.sleeping => 'Zzz… estoy recuperando energía.',
    PetMood.dirty => 'Un baño me haría sentir mejor.',
  };

  String get moodEmoji => switch (mood) {
    PetMood.happy => '😊',
    PetMood.sad => '🥺',
    PetMood.tired => '😴',
    PetMood.hungry => '🍽️',
    PetMood.excited => '🤩',
    PetMood.sleeping => '💤',
    PetMood.dirty => '🫧',
  };

  static int _stat(dynamic value, int fallback) {
    final parsed = value is num ? value.toInt() : fallback;
    return parsed.clamp(0, 100);
  }

  static String _safeName(dynamic value) {
    final name = value?.toString().trim() ?? '';
    return name.isEmpty || name.length > 30 ? 'Pawdo' : name;
  }
}
