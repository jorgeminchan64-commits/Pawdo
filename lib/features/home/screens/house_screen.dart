import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../economy/services/economy_service.dart';
import 'couple_room_screen.dart';

class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
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

  int _toInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  Map<String, dynamic> _houseTheme(String houseModel) {
    switch (houseModel) {
      case "modern_house":
        return {
          "name": "Casa Moderna",
          "emoji": "🏠",
          "wall": const Color(0xFFE3F2FD),
          "roof": const Color(0xFF424242),
          "border": const Color(0xFF90CAF9),
          "door": const Color(0xFF263238),
          "sky1": const Color(0xFFBDEBFF),
          "sky2": const Color(0xFFEAF7FF),
        };

      case "garden_house":
        return {
          "name": "Casa con Jardín",
          "emoji": "🌳",
          "wall": const Color(0xFFF1F8E9),
          "roof": const Color(0xFF66BB6A),
          "border": const Color(0xFF2E7D32),
          "door": const Color(0xFF8D6E63),
          "sky1": const Color(0xFFC8F7C5),
          "sky2": const Color(0xFFE9FBE7),
        };

      case "premium_mansion":
        return {
          "name": "Mansión Premium",
          "emoji": "🏰",
          "wall": const Color(0xFFFFF8E1),
          "roof": const Color(0xFF7E57C2),
          "border": const Color(0xFFFFD54F),
          "door": const Color(0xFF5D4037),
          "sky1": const Color(0xFFE1BEE7),
          "sky2": const Color(0xFFFFF3E0),
        };

      case "basic_house":
      default:
        return {
          "name": "Casa Básica",
          "emoji": "🏡",
          "wall": const Color(0xFFFFF3E0),
          "roof": const Color(0xFFE57373),
          "border": const Color(0xFFBCAAA4),
          "door": const Color(0xFF8D6E63),
          "sky1": const Color(0xFFBDEBFF),
          "sky2": const Color(0xFFE9F8E7),
        };
    }
  }

  Future<void> waterPlants(String coupleCode) async {
    await EconomyService().performAction(
      coupleCode: coupleCode,
      actionId: 'world_water',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Regaste las plantas 🌱 +10 monedas")),
    );
  }

  void enterHouse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoupleRoomScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleCodeFuture,
      builder: (context, coupleCodeSnapshot) {
        if (coupleCodeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final coupleCode = coupleCodeSnapshot.data;

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
            final plantsWatered = _toInt(data['plantsWatered'], 0);
            final houseModel = data['houseModel']?.toString() ?? "basic_house";

            final theme = _houseTheme(houseModel);
            final houseName = theme["name"].toString();

            return Scaffold(
              backgroundColor: const Color(0xFFE9F8E7),
              body: SafeArea(
                child: Stack(
                  children: [
                    // Fondo / cielo dinámico
                    Container(
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme["sky1"] as Color,
                            theme["sky2"] as Color,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Sol
                    Positioned(
                      top: 90,
                      right: 35,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.35),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Header
                    Positioned(
                      top: 18,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Nuestra Casa 🏡",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                houseName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          _coinBadge(coins),
                        ],
                      ),
                    ),

                    // Árboles
                    Positioned(
                      left: 18,
                      bottom: 210,
                      child: _tree(
                        big:
                            houseModel == "garden_house" ||
                            houseModel == "premium_mansion",
                      ),
                    ),

                    Positioned(
                      right: 18,
                      bottom: 230,
                      child: _tree(
                        big:
                            houseModel == "garden_house" ||
                            houseModel == "premium_mansion",
                      ),
                    ),

                    // Casa dinámica
                    Positioned(
                      left: 36,
                      right: 36,
                      bottom: 190,
                      child: GestureDetector(
                        onTap: enterHouse,
                        child: _buildHouse(houseModel),
                      ),
                    ),

                    // Jardín base
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: houseModel == "garden_house"
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFF75C76B),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(50),
                          ),
                        ),
                      ),
                    ),

                    // Flores extra si la casa es de jardín o premium
                    if (houseModel == "garden_house" ||
                        houseModel == "premium_mansion")
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 165,
                        child: Center(child: _flowerLine()),
                      ),

                    Positioned(left: 25, bottom: 105, child: _flowers()),

                    Positioned(right: 25, bottom: 105, child: _flowers()),

                    // Personitas
                    const Positioned(
                      left: 85,
                      bottom: 120,
                      child: Text("🧍‍♂️", style: TextStyle(fontSize: 54)),
                    ),

                    const Positioned(
                      right: 85,
                      bottom: 120,
                      child: Text("🧍‍♀️", style: TextStyle(fontSize: 54)),
                    ),

                    // Mascota
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 95,
                      child: Center(
                        child: Text("🐶", style: TextStyle(fontSize: 58)),
                      ),
                    ),

                    // Info plantas
                    Positioned(
                      left: 20,
                      bottom: 84,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          "Plantas regadas: $plantsWatered",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Botones inferiores
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              text: "Regar 🌱",
                              color: const Color(0xFF43A047),
                              onTap: () => waterPlants(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              text: "Entrar 🏡",
                              color: const Color(0xFF6C63FF),
                              onTap: enterHouse,
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
    );
  }

  Widget _buildHouse(String houseModel) {
    final theme = _houseTheme(houseModel);

    final wall = theme["wall"] as Color;
    final roof = theme["roof"] as Color;
    final border = theme["border"] as Color;
    final door = theme["door"] as Color;
    final emoji = theme["emoji"].toString();

    final bool isModern = houseModel == "modern_house";
    final bool isGarden = houseModel == "garden_house";
    final bool isPremium = houseModel == "premium_mansion";

    return Container(
      height: isPremium ? 240 : 215,
      decoration: BoxDecoration(
        color: wall,
        borderRadius: BorderRadius.circular(isModern ? 18 : 28),
        border: Border.all(color: border, width: isPremium ? 4 : 3),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Techo
          Positioned(
            top: isPremium ? -78 : -68,
            left: isPremium ? 5 : 18,
            right: isPremium ? 5 : 18,
            child: Container(
              height: isPremium ? 118 : 105,
              decoration: BoxDecoration(
                color: roof,
                borderRadius: BorderRadius.circular(isModern ? 14 : 24),
                boxShadow: [
                  BoxShadow(
                    color: roof.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: isPremium ? 62 : 56),
                ),
              ),
            ),
          ),

          // Decoración premium
          if (isPremium)
            const Positioned(
              top: 22,
              left: 0,
              right: 0,
              child: Center(
                child: Text("✨ 💎 ✨", style: TextStyle(fontSize: 26)),
              ),
            ),

          // Ventanas
          Positioned(
            top: isPremium ? 82 : 68,
            left: isPremium ? 30 : 35,
            child: Text(
              isModern ? "🔲" : "🪟",
              style: const TextStyle(fontSize: 42),
            ),
          ),

          Positioned(
            top: isPremium ? 82 : 68,
            right: isPremium ? 30 : 35,
            child: Text(
              isModern ? "🔲" : "🪟",
              style: const TextStyle(fontSize: 42),
            ),
          ),

          if (isGarden)
            const Positioned(
              top: 120,
              left: 20,
              child: Text("🌿", style: TextStyle(fontSize: 34)),
            ),

          if (isGarden)
            const Positioned(
              top: 120,
              right: 20,
              child: Text("🌿", style: TextStyle(fontSize: 34)),
            ),

          // Puerta
          Positioned(
            bottom: 0,
            left: isPremium ? 105 : 115,
            right: isPremium ? 105 : 115,
            child: Container(
              height: isPremium ? 95 : 85,
              decoration: BoxDecoration(
                color: door,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: const Center(
                child: Text("🚪", style: TextStyle(fontSize: 42)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tree({required bool big}) {
    return Column(
      children: [
        Container(
          width: big ? 105 : 90,
          height: big ? 105 : 90,
          decoration: const BoxDecoration(
            color: Color(0xFF2E7D32),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: big ? 34 : 28,
          height: big ? 80 : 70,
          color: Colors.brown,
        ),
      ],
    );
  }

  Widget _flowers() {
    return const Row(
      children: [
        Text("🌸", style: TextStyle(fontSize: 30)),
        Text("🌼", style: TextStyle(fontSize: 30)),
        Text("🌷", style: TextStyle(fontSize: 30)),
      ],
    );
  }

  Widget _flowerLine() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("🌸", style: TextStyle(fontSize: 28)),
        Text("🌼", style: TextStyle(fontSize: 28)),
        Text("🌷", style: TextStyle(fontSize: 28)),
        Text("🌺", style: TextStyle(fontSize: 28)),
        Text("🌻", style: TextStyle(fontSize: 28)),
      ],
    );
  }

  Widget _actionButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 6,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
