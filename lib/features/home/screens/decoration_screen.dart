import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DecorationScreen extends StatefulWidget {
  final String coupleCode;

  const DecorationScreen({super.key, required this.coupleCode});

  @override
  State<DecorationScreen> createState() => _DecorationScreenState();
}

class _DecorationScreenState extends State<DecorationScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool isLoading = true;
  bool isSaving = false;

  Map<String, Offset> furniturePositions = {
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
    loadFurniturePositions();
  }

  Future<void> loadFurniturePositions() async {
    try {
      final doc = await _db.collection('couples').doc(widget.coupleCode).get();
      final data = doc.data();

      if (data != null && data['furniturePositions'] != null) {
        final savedPositions = Map<String, dynamic>.from(
          data['furniturePositions'],
        );

        savedPositions.forEach((key, value) {
          if (value is Map) {
            final x = value['x'];
            final y = value['y'];

            if (x is num && y is num) {
              furniturePositions[key] = Offset(x.toDouble(), y.toDouble());
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando muebles: $e");
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveFurniturePositions() async {
    setState(() {
      isSaving = true;
    });

    final Map<String, dynamic> positionsToSave = {};

    furniturePositions.forEach((key, value) {
      positionsToSave[key] = {"x": value.dx, "y": value.dy};
    });

    await _db.collection('couples').doc(widget.coupleCode).set({
      "furniturePositions": positionsToSave,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Decoración guardada ✅")));
  }

  void resetFurniture() {
    setState(() {
      furniturePositions = {
        "bed": const Offset(30, 250),
        "sofa": const Offset(215, 250),
        "table": const Offset(140, 330),
        "tv": const Offset(35, 80),
        "plant": const Offset(270, 100),
        "lamp": const Offset(160, 120),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF1F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                          "Editar Casa 🛋️",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Arrastra los muebles",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: resetFurniture,
                    icon: const Icon(Icons.restart_alt),
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

                          // Ventana fija
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

                          // Muebles arrastrables
                          for (final id in furnitureData.keys)
                            _editableFurniture(id: id, areaSize: areaSize),

                          // Personitas y mascota fijas por ahora
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
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 45,
                            child: Center(
                              child: Text("🐶", style: TextStyle(fontSize: 54)),
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
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: isSaving ? null : saveFurniturePositions,
                  icon: const Icon(Icons.save),
                  label: Text(
                    isSaving ? "Guardando..." : "Guardar decoración",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableFurniture({required String id, required Size areaSize}) {
    final data = furnitureData[id]!;
    final emoji = data["emoji"].toString();
    final name = data["name"].toString();
    final size = data["size"] as double;

    final position = furniturePositions[id] ?? const Offset(20, 20);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final current = furniturePositions[id] ?? Offset.zero;

            double newX = current.dx + details.delta.dx;
            double newY = current.dy + details.delta.dy;

            if (newX < 0) newX = 0;
            if (newY < 0) newY = 0;
            if (newX > areaSize.width - size) {
              newX = areaSize.width - size;
            }
            if (newY > areaSize.height - size) {
              newY = areaSize.height - size;
            }

            furniturePositions[id] = Offset(newX, newY);
          });
        },
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
