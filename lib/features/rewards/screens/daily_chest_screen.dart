import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/daily_chest_rewards.dart';
import '../../economy/services/economy_service.dart';

class DailyChestScreen extends StatefulWidget {
  const DailyChestScreen({super.key});

  @override
  State<DailyChestScreen> createState() => _DailyChestScreenState();
}

class _DailyChestScreenState extends State<DailyChestScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Future<String?> _coupleCodeFuture;

  bool isClaiming = false;

  @override
  void initState() {
    super.initState();
    _coupleCodeFuture = _getCoupleCode();
  }

  Future<String?> _getCoupleCode() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    return userDoc.data()?['coupleCode']?.toString();
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  Map<String, dynamic> _dailyChestData(Map<String, dynamic> data) {
    final raw = data['dailyChest'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Future<void> _claimDailyChest(String coupleCode) async {
    if (isClaiming) return;

    setState(() => isClaiming = true);

    try {
      final result = await EconomyService().claimDailyReward(coupleCode);

      if (!mounted) return;

      if (result['alreadyClaimed'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya reclamaste el cofre de hoy ✅')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['title'] ?? 'Recompensa'}: +${result['coins'] ?? 0} monedas',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo reclamar el cofre. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isClaiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, codeSnapshot) {
        final coupleCode = codeSnapshot.data;

        if (codeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF3FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (coupleCode == null || coupleCode.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF3FA),
            body: Center(
              child: Text(
                'Primero necesitas estar vinculado con tu pareja.',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('couples').doc(coupleCode).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final chestData = _dailyChestData(data);

            final today = dailyChestDateKey();
            final lastClaimDate = chestData['lastClaimDate']?.toString();
            final currentStreak = _toInt(chestData['streak'], 0);
            final coins = _toInt(data['coins'], 0);

            final alreadyClaimedToday = lastClaimDate == today;

            int previewStreak;

            if (alreadyClaimedToday) {
              previewStreak = currentStreak;
            } else if (lastClaimDate == yesterdayChestDateKey()) {
              previewStreak = currentStreak + 1;
              if (previewStreak > 7) previewStreak = 1;
            } else {
              previewStreak = 1;
            }

            final todayReward = rewardForStreakDay(previewStreak);

            return Scaffold(
              backgroundColor: const Color(0xFFFFF3FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFFFFF3FA),
                elevation: 0,
                title: const Text(
                  'Cofre Diario 🎁',
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '🪙 $coins',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _mainChestCard(
                    reward: todayReward,
                    alreadyClaimed: alreadyClaimedToday,
                    streak: currentStreak,
                    previewStreak: previewStreak,
                    onClaim: () => _claimDailyChest(coupleCode),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Racha de 7 días',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...dailyChestRewards.map((reward) {
                    final active = reward.day == previewStreak;
                    final claimed =
                        alreadyClaimedToday &&
                        reward.day <= currentStreak &&
                        currentStreak != 0;

                    return _rewardCard(
                      reward: reward,
                      active: active,
                      claimed: claimed,
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _mainChestCard({
    required DailyChestReward reward,
    required bool alreadyClaimed,
    required int streak,
    required int previewStreak,
    required VoidCallback onClaim,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6EA), Color(0xFFEED7FF)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            alreadyClaimed ? '✅' : reward.emoji,
            style: const TextStyle(fontSize: 70),
          ),
          const SizedBox(height: 8),
          Text(
            alreadyClaimed
                ? 'Cofre reclamado hoy'
                : 'Día $previewStreak: ${reward.title}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alreadyClaimed
                ? 'Vuelve mañana para continuar tu racha.'
                : 'Recompensa: 🪙 ${reward.coins}  ❤️ ${reward.love}  ⚡ ${reward.energy}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: alreadyClaimed || isClaiming ? null : onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Text(
                isClaiming
                    ? 'Reclamando...'
                    : alreadyClaimed
                    ? 'Ya reclamado'
                    : 'Reclamar cofre',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard({
    required DailyChestReward reward,
    required bool active,
    required bool claimed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEED7FF) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active ? Colors.purple : Colors.transparent,
          width: active ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            claimed ? '✅' : reward.emoji,
            style: const TextStyle(fontSize: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Día ${reward.day} · ${reward.title}',
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '🪙 ${reward.coins}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
