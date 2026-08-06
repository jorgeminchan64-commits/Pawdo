class DailyChestReward {
  final int day;
  final int coins;
  final int love;
  final int energy;
  final String title;
  final String emoji;

  const DailyChestReward({
    required this.day,
    required this.coins,
    required this.love,
    required this.energy,
    required this.title,
    required this.emoji,
  });
}

const List<DailyChestReward> dailyChestRewards = [
  DailyChestReward(
    day: 1,
    coins: 30,
    love: 1,
    energy: 2,
    title: 'Inicio bonito',
    emoji: '🎁',
  ),
  DailyChestReward(
    day: 2,
    coins: 45,
    love: 2,
    energy: 2,
    title: 'Pareja constante',
    emoji: '💝',
  ),
  DailyChestReward(
    day: 3,
    coins: 60,
    love: 3,
    energy: 3,
    title: 'Cofre dulce',
    emoji: '🌸',
  ),
  DailyChestReward(
    day: 4,
    coins: 80,
    love: 4,
    energy: 4,
    title: 'Racha Pawdo',
    emoji: '🐶',
  ),
  DailyChestReward(
    day: 5,
    coins: 110,
    love: 5,
    energy: 5,
    title: 'Cofre romántico',
    emoji: '❤️',
  ),
  DailyChestReward(
    day: 6,
    coins: 140,
    love: 6,
    energy: 6,
    title: 'Casi premio grande',
    emoji: '✨',
  ),
  DailyChestReward(
    day: 7,
    coins: 220,
    love: 10,
    energy: 10,
    title: 'Cofre legendario',
    emoji: '👑',
  ),
];

DailyChestReward rewardForStreakDay(int streakDay) {
  final normalizedDay = streakDay.clamp(1, 7);

  for (final reward in dailyChestRewards) {
    if (reward.day == normalizedDay) return reward;
  }

  return dailyChestRewards.first;
}

String dailyChestDateKey([DateTime? date]) {
  final value = date ?? DateTime.now();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  return '${value.year}-$month-$day';
}

String yesterdayChestDateKey() {
  return dailyChestDateKey(
    DateTime.now().subtract(const Duration(days: 1)),
  );
}