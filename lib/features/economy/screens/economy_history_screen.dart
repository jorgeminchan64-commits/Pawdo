import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EconomyHistoryScreen extends StatefulWidget {
  const EconomyHistoryScreen({super.key});

  @override
  State<EconomyHistoryScreen> createState() => _EconomyHistoryScreenState();
}

class _EconomyHistoryScreenState extends State<EconomyHistoryScreen> {
  late final Future<String?> _coupleCode = _loadCoupleCode();

  Future<String?> _loadCoupleCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return profile.data()?['coupleCode']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        title: const Text('Historial compartido'),
      ),
      body: FutureBuilder<String?>(
        future: _coupleCode,
        builder: (context, codeSnapshot) {
          if (codeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final code = codeSnapshot.data;
          if (code == null || code.isEmpty) {
            return const _EmptyHistory(
              message: 'Vincúlate con tu pareja para ver el historial.',
            );
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('couples')
                .doc(code)
                .collection('economyLedger')
                .orderBy('createdAt', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _EmptyHistory(
                  message: 'No se pudo cargar el historial. Intenta de nuevo.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!.docs;
              if (entries.isEmpty) {
                return const _EmptyHistory(
                  message:
                      'Las próximas compras y recompensas aparecerán aquí.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = entries[index].data();
                  final delta = (data['deltaCoins'] as num?)?.toInt() ?? 0;
                  final balance = (data['balanceAfter'] as num?)?.toInt();
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE6F2),
                        child: Icon(_icon(data['type']?.toString())),
                      ),
                      title: Text(
                        _title(data),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: balance == null
                          ? null
                          : Text('Saldo después: $balance monedas'),
                      trailing: Text(
                        '${delta > 0 ? '+' : ''}$delta',
                        style: TextStyle(
                          color: delta < 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_bag_outlined;
      case 'daily_reward':
        return Icons.card_giftcard;
      default:
        return Icons.favorite_outline;
    }
  }

  String _title(Map<String, dynamic> data) {
    switch (data['type']?.toString()) {
      case 'purchase':
        return 'Compra: ${data['itemName'] ?? data['itemId'] ?? 'objeto'}';
      case 'daily_reward':
        return 'Cofre diario';
      case 'action':
        return 'Actividad: ${data['actionId'] ?? 'compartida'}';
      default:
        return 'Movimiento de economía';
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
