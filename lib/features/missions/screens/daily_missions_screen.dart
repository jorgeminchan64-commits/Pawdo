import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../rewards/screens/daily_chest_screen.dart';
import '../data/daily_missions_data.dart';

class DailyMissionsScreen extends StatefulWidget {
  const DailyMissionsScreen({super.key});

  @override
  State<DailyMissionsScreen> createState() => _DailyMissionsScreenState();
}

class _DailyMissionsScreenState extends State<DailyMissionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Future<String?> _coupleCodeFuture;

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

  Map<String, dynamic> _missionDataFromCouple(Map<String, dynamic> data) {
    final raw = data['dailyMissions'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Set<String> _completedMissionIds(Map<String, dynamic> data) {
    final missionsData = _missionDataFromCouple(data);
    final today = todayMissionKey();

    if (missionsData['date']?.toString() != today) {
      return {};
    }

    final completed = missionsData['completed'];

    if (completed is Map) {
      return completed.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toSet();
    }

    return {};
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
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
            final completedIds = _completedMissionIds(data);
            final coins = _toInt(data['coins'], 0);
            final completedCount = completedIds.length;
            final totalCount = dailyMissions.length;
            final progress = totalCount == 0
                ? 0.0
                : completedCount / totalCount;

            return Scaffold(
              backgroundColor: const Color(0xFFFFF3FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFFFFF3FA),
                elevation: 0,
                title: const Text(
                  'Misiones Diarias 🎯',
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
                  _headerCard(
                    completed: completedCount,
                    total: totalCount,
                    progress: progress,
                  ),
                  const SizedBox(height: 16),
                  _dailyChestShortcut(context),
                  const SizedBox(height: 16),
                  ...dailyMissions.map((mission) {
                    final completed = completedIds.contains(mission.id);

                    return _missionCard(mission: mission, completed: completed);
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _headerCard({
    required int completed,
    required int total,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6EA), Color(0xFFFFF2F8)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completa acciones para ganar recompensas una vez al día.',
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed / $total completadas hoy',
            style: const TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyChestShortcut(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyChestScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cofre diario',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reclama recompensas y mantén tu racha de 7 días.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.purple,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionCard({
    required DailyMission mission,
    required bool completed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: completed ? Colors.green : Colors.transparent,
          width: completed ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: completed ? Colors.green.shade50 : const Color(0xFFFFF3FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                completed ? '✅' : mission.emoji,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mission.description,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Recompensa: 🪙 ${mission.coinsReward}  ❤️ ${mission.loveReward}  ⚡ ${mission.energyReward}',
                  style: TextStyle(
                    color: completed ? Colors.green : Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
