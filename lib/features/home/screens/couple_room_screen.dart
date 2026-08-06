import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../economy/services/economy_service.dart';

import 'decoration_screen.dart';

class CoupleRoomScreen extends StatefulWidget {
  const CoupleRoomScreen({super.key});

  @override
  State<CoupleRoomScreen> createState() => _CoupleRoomScreenState();
}

class _CoupleRoomScreenState extends State<CoupleRoomScreen> {
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

  int _limit100(int value) {
    if (value > 100) return 100;
    if (value < 0) return 0;
    return value;
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
      loveAdd: 6,
      energyAdd: 18,
      action: "Descansaron juntos en su cuarto",
      message: "Descansaron juntos. Energía +18",
    );
  }

  Future<void> eatTogether(String coupleCode) async {
    await _updateStats(
      coupleCode: coupleCode,
      actionId: 'room_eat',
      coinsAdd: 6,
      loveAdd: 4,
      energyAdd: 10,
      action: "Comieron juntos en casa",
      message: "Comieron juntos. +6 monedas",
    );
  }

  Future<void> watchMovie(String coupleCode) async {
    await _updateStats(
      coupleCode: coupleCode,
      actionId: 'room_movie',
      coinsAdd: 10,
      loveAdd: 14,
      energyAdd: -4,
      action: "Vieron una película juntos",
      message: "Película en pareja. Amor +14",
    );
  }

  void voiceRoom() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pronto agregaremos notas de voz y micrófono en vivo"),
      ),
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
                data['lastAction']?.toString() ?? "Bienvenidos a su espacio";

            return Scaffold(
              backgroundColor: const Color(0xFFFFEEF5),
              body: SafeArea(
                child: Column(
                  children: [
                    _header(coins),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: "Amor",
                              value: love,
                              icon: Icons.favorite,
                              color: Colors.pinkAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: "Energía",
                              value: energy,
                              icon: Icons.bolt,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(child: _bigCoupleRoom(lastAction)),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              text: "Dormir",
                              icon: Icons.hotel,
                              color: const Color(0xFF6C63FF),
                              onTap: () => sleepTogether(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              text: "Comer",
                              icon: Icons.restaurant,
                              color: const Color(0xFF43A047),
                              onTap: () => eatTogether(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              text: "Peli",
                              icon: Icons.movie,
                              color: const Color(0xFFE91E63),
                              onTap: () => watchMovie(coupleCode),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              text: "Voz",
                              icon: Icons.mic,
                              color: const Color(0xFF0097A7),
                              onTap: voiceRoom,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              text: "Editar",
                              icon: Icons.chair,
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

  Widget _header(int coins) {
    return Padding(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Espacio de Pareja",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Su cuarto compartido en Pawdo",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              "🪙 $coins",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigCoupleRoom(String lastAction) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomHeight = constraints.maxHeight;
        const roomWidth = 1350.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: roomWidth,
                height: roomHeight,
                child: Stack(
                  children: [
                    // Pared
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: roomHeight * 0.62,
                      child: Container(color: const Color(0xFFFFDDE8)),
                    ),

                    // Patrón de pared
                    for (int i = 0; i < 22; i++)
                      Positioned(
                        left: i * 65,
                        top: 0,
                        bottom: roomHeight * 0.38,
                        child: Container(
                          width: 2,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),

                    for (int i = 0; i < 12; i++)
                      Positioned(
                        left: 65.0 + (i * 105),
                        top: 42,
                        child: Icon(
                          Icons.favorite_border,
                          color: Colors.white.withOpacity(0.45),
                          size: 22,
                        ),
                      ),

                    // Piso
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: roomHeight * 0.42,
                      child: Container(color: const Color(0xFF78C9C9)),
                    ),

                    for (int i = 0; i < 8; i++)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: i * 38.0,
                        child: Container(
                          height: 1,
                          color: Colors.teal.withOpacity(0.25),
                        ),
                      ),

                    // Decoración pared
                    Positioned(top: 35, left: 310, child: _photoFrame()),

                    Positioned(top: 95, left: 455, child: _smallFrame()),

                    Positioned(top: 68, left: 600, child: _relationshipBoard()),

                    Positioned(top: 52, left: 800, child: _wallShelf()),

                    Positioned(top: 105, left: 760, child: _miniShelves()),

                    Positioned(top: 120, left: 45, child: _dressStand()),

                    Positioned(top: 130, left: 135, child: _window()),

                    Positioned(top: 90, left: 380, child: _hangingPlant()),

                    // Muebles principales
                    Positioned(left: 360, bottom: 130, child: _sofa()),

                    Positioned(left: 250, bottom: 70, child: _bigRug()),

                    Positioned(left: 225, bottom: 135, child: _coffeeTable()),

                    Positioned(left: 675, bottom: 135, child: _tvStand()),

                    Positioned(left: 870, bottom: 145, child: _bookCase()),

                    Positioned(left: 1080, bottom: 145, child: _fridge()),

                    Positioned(left: 955, bottom: 60, child: _petHouse()),

                    Positioned(left: 70, top: 48, child: _plantShelf()),

                    Positioned(left: 815, bottom: 72, child: _recordPlayer()),

                    // Personajes grandes
                    Positioned(
                      left: 360,
                      bottom: 70,
                      child: _personAvatar(
                        name: "Tú",
                        shirtColor: const Color(0xFF4B6CB7),
                        pantsColor: const Color(0xFFF9F5EF),
                        hairColor: const Color(0xFF5D4037),
                      ),
                    ),

                    Positioned(
                      left: 485,
                      bottom: 54,
                      child: _personAvatar(
                        name: "Pareja",
                        shirtColor: const Color(0xFFFFA6C9),
                        pantsColor: const Color(0xFF7E57C2),
                        hairColor: const Color(0xFF8D4A64),
                        feminine: true,
                      ),
                    ),

                    Positioned(left: 785, bottom: 63, child: _dog()),

                    // Mensaje
                    Positioned(
                      left: 630,
                      bottom: 128,
                      child: _messageBubble(lastAction),
                    ),

                    // Hint scroll
                    Positioned(
                      right: 20,
                      bottom: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.swipe, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Desliza para ver toda la casa",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 9),
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

  Widget _actionButton({
    required String text,
    required IconData icon,
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
            Icon(icon, size: 19),
            Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _window() {
    return SizedBox(
      width: 230,
      height: 150,
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 10,
            child: Container(
              width: 190,
              height: 105,
              decoration: BoxDecoration(
                color: const Color(0xFFB9EAFB),
                border: Border.all(color: Colors.brown.shade300, width: 3),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 93,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Colors.brown.shade300),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 50,
                    child: Container(height: 3, color: Colors.brown.shade300),
                  ),
                  const Positioned(
                    right: 25,
                    top: 20,
                    child: Icon(Icons.nightlight_round, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 65,
              height: 125,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA6C9),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 65,
              height: 125,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA6C9),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sofa() {
    return Container(
      width: 300,
      height: 115,
      decoration: BoxDecoration(
        color: const Color(0xFF2FA7B5),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 18,
            child: _pillow(const Color(0xFFFFD166)),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: _pillow(const Color(0xFFFF8FAB)),
          ),
          Positioned(
            left: 112,
            top: 20,
            child: Container(
              width: 72,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.pets, color: Colors.pinkAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillow(Color color) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _coffeeTable() {
    return Container(
      width: 175,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFF8D47B),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_cafe, color: Colors.brown),
          SizedBox(width: 10),
          Icon(Icons.cake, color: Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _bigRug() {
    return Container(
      width: 370,
      height: 105,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB3C7),
        borderRadius: BorderRadius.circular(90),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
    );
  }

  Widget _tvStand() {
    return Column(
      children: [
        Container(
          width: 135,
          height: 85,
          decoration: BoxDecoration(
            color: const Color(0xFFB6F1F4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.brown.shade300, width: 2),
          ),
          child: const Icon(Icons.tv, size: 48, color: Color(0xFF6C63FF)),
        ),
        Container(
          width: 160,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF35A7B7),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ],
    );
  }

  Widget _bookCase() {
    return Container(
      width: 175,
      height: 235,
      decoration: BoxDecoration(
        color: const Color(0xFFFFA6C9),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _shelfRow(Icons.camera_alt, Icons.favorite),
          _shelfRow(Icons.menu_book, Icons.public),
          _shelfRow(Icons.photo_album, Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _shelfRow(IconData a, IconData b) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(a, color: Colors.white, size: 28),
          Icon(b, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _fridge() {
    return Container(
      width: 155,
      height: 255,
      decoration: BoxDecoration(
        color: const Color(0xFFFF9FBD),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 95,
            left: 0,
            right: 0,
            child: Container(height: 2, color: Colors.brown.shade300),
          ),
          const Positioned(
            top: 35,
            left: 42,
            child: Icon(Icons.sticky_note_2, color: Colors.white, size: 32),
          ),
          const Positioned(
            top: 145,
            left: 44,
            child: Icon(Icons.favorite, color: Colors.white, size: 45),
          ),
        ],
      ),
    );
  }

  Widget _petHouse() {
    return Container(
      width: 130,
      height: 95,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB3C7),
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.pets, size: 45, color: Colors.brown),
      ),
    );
  }

  Widget _plantShelf() {
    return Column(
      children: [
        Container(width: 100, height: 8, color: const Color(0xFF6C63FF)),
        const SizedBox(height: 12),
        Container(width: 120, height: 8, color: const Color(0xFF6C63FF)),
        const SizedBox(height: 12),
        Container(width: 90, height: 8, color: const Color(0xFF6C63FF)),
      ],
    );
  }

  Widget _dressStand() {
    return SizedBox(
      width: 90,
      height: 165,
      child: Stack(
        children: [
          Positioned(
            left: 40,
            top: 0,
            child: Container(
              width: 8,
              height: 145,
              color: Colors.brown.shade300,
            ),
          ),
          Positioned(
            left: 15,
            top: 50,
            child: Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.pinkAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoFrame() {
    return Transform.rotate(
      angle: 0.08,
      child: Container(
        width: 90,
        height: 70,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.brown.shade300,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFFA6C9)],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Icon(Icons.people, color: Colors.white, size: 35),
        ),
      ),
    );
  }

  Widget _smallFrame() {
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        width: 70,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.brown.shade300, width: 3),
        ),
        child: const Icon(Icons.landscape, color: Colors.orangeAccent),
      ),
    );
  }

  Widget _relationshipBoard() {
    return Container(
      width: 130,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.shade300, width: 3),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Juntos", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              "44 días",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wallShelf() {
    return Container(width: 105, height: 8, color: Colors.brown.shade300);
  }

  Widget _miniShelves() {
    return Column(
      children: [
        Container(width: 125, height: 8, color: Colors.brown.shade300),
        const SizedBox(height: 35),
        Container(width: 110, height: 8, color: Colors.brown.shade300),
      ],
    );
  }

  Widget _hangingPlant() {
    return Column(
      children: [
        Container(
          width: 95,
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD166),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: Icon(Icons.local_florist, color: Colors.pinkAccent),
          ),
        ),
      ],
    );
  }

  Widget _recordPlayer() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFFFD166),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.music_note, color: Colors.white),
        ),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8D6E63),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _messageBubble(String text) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _personAvatar({
    required String name,
    required Color shirtColor,
    required Color pantsColor,
    required Color hairColor,
    bool feminine = false,
  }) {
    return SizedBox(
      width: 115,
      height: 205,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFCCBC),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 62,
              height: feminine ? 42 : 28,
              decoration: BoxDecoration(
                color: hairColor,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Positioned(
            top: 22,
            left: 42,
            child: Container(width: 5, height: 5, color: Colors.black87),
          ),
          Positioned(
            top: 22,
            right: 42,
            child: Container(width: 5, height: 5, color: Colors.black87),
          ),
          Positioned(
            top: 68,
            child: Container(
              width: 70,
              height: 78,
              decoration: BoxDecoration(
                color: shirtColor,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Positioned(
            top: 135,
            left: 28,
            child: Container(
              width: 24,
              height: 55,
              decoration: BoxDecoration(
                color: pantsColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 135,
            right: 28,
            child: Container(
              width: 24,
              height: 55,
              decoration: BoxDecoration(
                color: pantsColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dog() {
    return SizedBox(
      width: 85,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 5,
            child: Container(
              width: 65,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: Container(
              width: 45,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD166),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 22,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 18,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.brown.shade300,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 22,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: 18,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.brown.shade300,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 25,
            child: Icon(Icons.favorite, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }
}
