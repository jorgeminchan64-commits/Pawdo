import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../economy/services/economy_service.dart';

import 'decoration_screen.dart';

class InteriorHouseScreen extends StatefulWidget {
  const InteriorHouseScreen({super.key});

  @override
  State<InteriorHouseScreen> createState() => _InteriorHouseScreenState();
}

class _InteriorHouseScreenState extends State<InteriorHouseScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Future<String?> _coupleCodeFuture;

  final Map<String, Offset> defaultFurniturePositions = {
    "bed": const Offset(30, 250),
    "sofa": const Offset(215, 250),
    "table": const Offset(140, 330),
    "tv": const Offset(35, 80),
    "plant": const Offset(270, 100),
    "lamp": const Offset(160, 120),
  };

  final Map<String, Map<String, dynamic>> furnitureData = {
    "bed": {"emoji": "🛏️", "name": "Cama", "size": 70.0},
    "sofa": {"emoji": "🛋️", "name": "Sofá", "size": 68.0},
    "table": {"emoji": "🍽️", "name": "Mesa", "size": 62.0},
    "tv": {"emoji": "📺", "name": "TV", "size": 62.0},
    "plant": {"emoji": "🪴", "name": "Planta", "size": 60.0},
    "lamp": {"emoji": "💡", "name": "Lámpara", "size": 58.0},
  };

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

  Map<String, Offset> _getFurniturePositions(Map<String, dynamic> data) {
    final Map<String, Offset> positions = Map.from(defaultFurniturePositions);

    if (data['furniturePositions'] != null) {
      final savedPositions = Map<String, dynamic>.from(
        data['furniturePositions'],
      );

      savedPositions.forEach((key, value) {
        if (value is Map) {
          final x = value['x'];
          final y = value['y'];

          if (x is num && y is num) {
            positions[key] = Offset(x.toDouble(), y.toDouble());
          }
        }
      });
    }

    return positions;
  }

  Future<void> _updateStats({
    required String coupleCode,
    required String actionId,
    required int coinsAdd,
    required int loveAdd,
    required int energyAdd,
    required String action,
    required String message,
  }) async {
    await EconomyService().performAction(
      coupleCode: coupleCode,
      actionId: actionId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Future<void> sleepTogether(String coupleCode) async {
    await _updateStats(
      coupleCode: coupleCode,
      actionId: 'room_sleep',
      coinsAdd: 0,
      loveAdd: 5,
      energyAdd: 15,
      action: "Descansaron juntos 😴",
      message: "Durmieron juntos 😴 Energía +15",
    );
  }

  Future<void> eatTogether(String coupleCode) async {
    await _updateStats(
      coupleCode: coupleCode,
      actionId: 'room_eat',
      coinsAdd: 5,
      loveAdd: 4,
      energyAdd: 8,
      action: "Comieron juntos 🍽️",
      message: "Comieron juntos 🍽️ +5 monedas",
    );
  }

  Future<void> watchMovie(String coupleCode) async {
    await _updateStats(
      coupleCode: coupleCode,
      actionId: 'room_movie',
      coinsAdd: 8,
      loveAdd: 12,
      energyAdd: -5,
      action: "Vieron una película romántica 🎬",
      message: "Película romántica 🎬 Amor +12, monedas +8",
    );
  }

  void decorateHouse(String coupleCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DecorationScreen(coupleCode: coupleCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, codeSnapshot) {
        if (codeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final coupleCode = codeSnapshot.data;

        if (coupleCode == null || coupleCode.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("No se encontró la pareja conectada")),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('couples').doc(coupleCode).snapshots(),
          builder: (context, coupleSnapshot) {
            if (coupleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = coupleSnapshot.data?.data() ?? {};

            final coins = _toInt(data['coins'], 0);
            final love = _toInt(data['love'], 80);
            final energy = _toInt(data['energy'], 65);
            final lastAction =
                data['lastAction']?.toString() ?? "Bienvenidos a su casita ❤️";

            final furniturePositions = _getFurniturePositions(data);

            return Scaffold(
              backgroundColor: const Color(0xFFFDF1F7),
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Interior de Casa 🏠",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _coinBadge(coins),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: "Amor",
                              value: love,
                              icon: "❤️",
                              color: Colors.pinkAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: "Energía",
                              value: energy,
                              icon: "⚡",
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD6E7), Color(0xFFFFF7EC)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final areaSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );

                              return Stack(
                                children: [
                                  // Pared
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: areaSize.height * 0.48,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFF9F2),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(26),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Piso
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: areaSize.height * 0.55,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE8C39E),
                                        borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(26),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Ventana
                                  Positioned(
                                    top: 35,
                                    right: 35,
                                    child: Container(
                                      width: 85,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBDEBFF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.brown.shade300,
                                          width: 4,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "☀️",
                                          style: TextStyle(fontSize: 26),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Muebles guardados
                                  for (final id in furnitureData.keys)
                                    _furniture(
                                      id: id,
                                      positions: furniturePositions,
                                      areaSize: areaSize,
                                    ),

                                  // Personitas
                                  const Positioned(
                                    left: 95,
                                    bottom: 80,
                                    child: Text(
                                      "🧍‍♂️",
                                      style: TextStyle(fontSize: 55),
                                    ),
                                  ),
                                  const Positioned(
                                    right: 95,
                                    bottom: 80,
                                    child: Text(
                                      "🧍‍♀️",
                                      style: TextStyle(fontSize: 55),
                                    ),
                                  ),

                                  // Mascota
                                  const Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 45,
                                    child: Center(
                                      child: Text(
                                        "🐶",
                                        style: TextStyle(fontSize: 54),
                                      ),
                                    ),
                                  ),

                                  // Última acción
                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        lastAction,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _smallActionButton(
                              text: "Dormir",
                              icon: "😴",
                              color: const Color(0xFF6C63FF),
                              onTap: () => sleepTogether(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _smallActionButton(
                              text: "Comer",
                              icon: "🍽️",
                              color: const Color(0xFF43A047),
                              onTap: () => eatTogether(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _smallActionButton(
                              text: "Peli",
                              icon: "🎬",
                              color: const Color(0xFFE91E63),
                              onTap: () => watchMovie(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _smallActionButton(
                              text: "Editar",
                              icon: "🛋️",
                              color: const Color(0xFFFF9800),
                              onTap: () => decorateHouse(coupleCode),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _furniture({
    required String id,
    required Map<String, Offset> positions,
    required Size areaSize,
  }) {
    final item = furnitureData[id]!;
    final emoji = item["emoji"].toString();
    final size = item["size"] as double;

    final savedPosition = positions[id] ?? const Offset(20, 20);

    double left = savedPosition.dx;
    double top = savedPosition.dy;

    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (left > areaSize.width - size) {
      left = areaSize.width - size;
    }
    if (top > areaSize.height - size) {
      top = areaSize.height - size;
    }

    return Positioned(
      left: left,
      top: top,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }

  Widget _coinBadge(int coins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        "🪙 $coins",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$title $value%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required String text,
    required String icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 5,
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
