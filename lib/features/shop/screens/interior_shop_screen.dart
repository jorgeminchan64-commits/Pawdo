import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/interior_shop_items.dart';
import '../../economy/services/economy_service.dart';

class InteriorShopScreen extends StatefulWidget {
  const InteriorShopScreen({super.key});

  @override
  State<InteriorShopScreen> createState() => _InteriorShopScreenState();
}

class _InteriorShopScreenState extends State<InteriorShopScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Future<String?> _coupleCodeFuture;
  final Set<String> _purchasingIds = <String>{};

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

  Set<String> _ownedItemsFromData(Map<String, dynamic> data) {
    final rawOwned = data['ownedInteriorItems'];

    if (rawOwned is List) {
      return rawOwned.map((item) => item.toString()).toSet();
    }

    return {};
  }

  Future<void> _buyItem({
    required InteriorShopItem item,
    required String coupleCode,
  }) async {
    if (item.isRealMoney || item.comingSoonPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este mueble premium estará disponible más adelante 💎',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text(
          '¿Comprar ${item.name} por ${item.price} monedas? La compra es compartida con tu pareja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Comprar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _purchasingIds.add(item.id));

    try {
      final result = await EconomyService().purchaseItem(
        coupleCode: coupleCode,
        itemId: item.id,
      );

      if (!mounted) return;

      final alreadyOwned = result['alreadyOwned'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyOwned
                ? '${item.name} ya pertenecía al inventario compartido.'
                : '${item.name} comprado. Recibo: ${result['receiptId'] ?? item.id}',
          ),
        ),
      );
    } on EconomyException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _purchasingIds.remove(item.id));
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
            final coins = _toInt(data['coins'], 0);
            final ownedItems = _ownedItemsFromData(data);

            return Scaffold(
              backgroundColor: const Color(0xFFFFF3FA),
              appBar: AppBar(
                backgroundColor: const Color(0xFFFFF3FA),
                elevation: 0,
                title: const Text(
                  'Tienda Interior 🛋️',
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
                  _headerCard(),
                  const SizedBox(height: 16),
                  _sectionTitle('Muebles con monedas'),
                  const SizedBox(height: 10),
                  ...interiorShopItems.map(
                    (item) => _shopCard(
                      item: item,
                      coupleCode: coupleCode,
                      owned: ownedItems.contains(item.id),
                      coins: coins,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6EA), Color(0xFFFFF2F8)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        children: [
          Text('🛋️', style: TextStyle(fontSize: 36)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Compra muebles para decorar el interior de la casa Pawdo.',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.purple,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _shopCard({
    required InteriorShopItem item,
    required String coupleCode,
    required bool owned,
    required int coins,
  }) {
    final canBuy = coins >= item.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            width: 96,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Image.asset(
                'assets/images/${item.assetPath}',
                fit: BoxFit.contain,
                cacheWidth: 288,
                errorBuilder: (_, _, _) {
                  return Center(
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 34),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.emoji} ${item.name}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Precio: 🪙 ${item.price}',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buyButton(
            item: item,
            coupleCode: coupleCode,
            owned: owned,
            canBuy: canBuy,
          ),
        ],
      ),
    );
  }

  Widget _buyButton({
    required InteriorShopItem item,
    required String coupleCode,
    required bool owned,
    required bool canBuy,
  }) {
    final purchasing = _purchasingIds.contains(item.id);
    if (owned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Comprado',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: canBuy && !purchasing
          ? () => _buyItem(item: item, coupleCode: coupleCode)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: purchasing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              canBuy ? 'Comprar' : 'Faltan monedas',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }
}
