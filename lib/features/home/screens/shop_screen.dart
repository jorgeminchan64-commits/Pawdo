import 'package:flutter/material.dart';

import '../../shop/screens/garden_shop_screen.dart';
import '../../shop/screens/interior_shop_screen.dart';
import '../../economy/screens/economy_history_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        elevation: 0,
        title: const Text(
          'Tienda Pawdo 🛍️',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _shopOption(
            context: context,
            title: 'Tienda Jardín',
            subtitle: 'Compra flores, árboles, decoraciones y casas.',
            emoji: '🌸',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GardenShopScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          _shopOption(
            context: context,
            title: 'Tienda Interior',
            subtitle: 'Compra cama, sofá, mesa, TV y muebles de casa.',
            emoji: '🛋️',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InteriorShopScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          _shopOption(
            context: context,
            title: 'Historial compartido',
            subtitle:
                'Consulta compras y recompensas verificadas por el servidor.',
            emoji: '🧾',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EconomyHistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shopOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String emoji,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF8),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 13,
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
}
