class DailyMission {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int coinsReward;
  final int loveReward;
  final int energyReward;

  const DailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.coinsReward,
    required this.loveReward,
    required this.energyReward,
  });
}

const List<DailyMission> dailyMissions = [
  DailyMission(
    id: 'water_plant',
    title: 'Regar una planta',
    description: 'Cuida el jardín o una planta interior.',
    emoji: '🌱',
    coinsReward: 15,
    loveReward: 2,
    energyReward: 0,
  ),
  DailyMission(
    id: 'pet_pawdo',
    title: 'Acariciar a Pawdo',
    description: 'Dale cariño a Pawdo una vez al día.',
    emoji: '🐶',
    coinsReward: 12,
    loveReward: 3,
    energyReward: 0,
  ),
  DailyMission(
    id: 'sit_together',
    title: 'Sentarse juntos',
    description: 'Tengan un momento bonito juntos.',
    emoji: '🛋️',
    coinsReward: 15,
    loveReward: 4,
    energyReward: 2,
  ),
  DailyMission(
    id: 'watch_movie',
    title: 'Ver una película',
    description: 'Disfruten una película romántica.',
    emoji: '🎬',
    coinsReward: 20,
    loveReward: 5,
    energyReward: 0,
  ),
  DailyMission(
    id: 'eat_together',
    title: 'Comer juntos',
    description: 'Compartan una comida dentro de casa.',
    emoji: '🍽️',
    coinsReward: 15,
    loveReward: 3,
    energyReward: 3,
  ),
  DailyMission(
    id: 'sleep_together',
    title: 'Descansar juntos',
    description: 'Recuperen energía descansando.',
    emoji: '😴',
    coinsReward: 10,
    loveReward: 2,
    energyReward: 5,
  ),
  DailyMission(
    id: 'hug_partner',
    title: 'Abrazo de pareja',
    description: 'Un abrazo aumenta el amor.',
    emoji: '❤️',
    coinsReward: 10,
    loveReward: 5,
    energyReward: 0,
  ),
];

DailyMission? findDailyMissionById(String id) {
  for (final mission in dailyMissions) {
    if (mission.id == id) return mission;
  }

  return null;
}

String todayMissionKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');

  return '${now.year}-$month-$day';
}

String? missionIdFromAction(String action) {
  final text = action.toLowerCase();

  if (text.contains('planta') || text.contains('regaron')) {
    return 'water_plant';
  }

  if (text.contains('pawdo') || text.contains('acariciaron')) {
    return 'pet_pawdo';
  }

  if (text.contains('sentaron') || text.contains('sofá') || text.contains('sofa')) {
    return 'sit_together';
  }

  if (text.contains('película') || text.contains('pelicula') || text.contains('peli')) {
    return 'watch_movie';
  }

  if (text.contains('comieron') || text.contains('comer')) {
    return 'eat_together';
  }

  if (text.contains('descansaron') || text.contains('dormir') || text.contains('durmieron')) {
    return 'sleep_together';
  }

  if (text.contains('abrazo')) {
    return 'hug_partner';
  }

  return null;
}