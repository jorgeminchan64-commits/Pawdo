import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../services/pet_service.dart';

class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, profile) {
        final code = profile.data?.data()?['coupleCode']?.toString();
        if (code == null || code.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Conecta a tu pareja para cuidar a Pawdo.'),
            ),
          );
        }
        final service = ref.read(petServiceProvider);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: service.watch(code),
          builder: (context, snapshot) {
            final pet = snapshot.data?.data() ?? const <String, dynamic>{};
            int stat(String key, int fallback) =>
                (pet[key] as num?)?.toInt() ?? fallback;
            return Scaffold(
              appBar: AppBar(title: const Text('Pawdo'), centerTitle: true),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 180,
                      height: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE8F2),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/pets/dog_01.png',
                        fit: BoxFit.contain,
                        cacheWidth: 420,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pet['name']?.toString() ?? 'Pawdo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 32),
                    _Stat(
                      label: 'Hambre',
                      value: stat('hunger', 70),
                      color: Colors.orange,
                    ),
                    _Stat(
                      label: 'Felicidad',
                      value: stat('happiness', 80),
                      color: Colors.pink,
                    ),
                    _Stat(
                      label: 'Energía',
                      value: stat('energy', 65),
                      color: Colors.blue,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Action(
                          icon: Icons.restaurant,
                          label: 'Alimentar',
                          onTap: () =>
                              service.performAction(code, PetAction.feed),
                        ),
                        _Action(
                          icon: Icons.sports_tennis,
                          label: 'Jugar',
                          onTap: () =>
                              service.performAction(code, PetAction.play),
                        ),
                        _Action(
                          icon: Icons.bedtime,
                          label: 'Dormir',
                          onTap: () =>
                              service.performAction(code, PetAction.sleep),
                        ),
                      ],
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
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text('$value%')],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value / 100,
          color: color,
          minHeight: 12,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton.filled(onPressed: onTap, icon: Icon(icon)),
      Text(label),
    ],
  );
}
