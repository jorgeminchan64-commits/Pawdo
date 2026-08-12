import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../models/pet_state.dart';
import '../services/pet_service.dart';

class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});

  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  PetAction? _busyAction;
  String? _localReaction;

  Future<void> _perform(
    PetService service,
    String code,
    PetAction action,
  ) async {
    if (_busyAction != null) return;
    setState(() {
      _busyAction = action;
      _localReaction = _reactionFor(action);
    });
    try {
      final result = await service.performAction(code, action);
      final message = result['message']?.toString();
      if (mounted && message != null && message.isNotEmpty) {
        setState(() => _localReaction = message);
      }
    } on PetException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (snapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('No se pudo cargar a Pawdo.')),
              );
            }
            final pet = PetState.fromMap(snapshot.data?.data());
            return Scaffold(
              appBar: AppBar(
                title: Text(pet.name),
                centerTitle: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '${pet.moodEmoji} ${pet.moodLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _busyAction == null
                            ? () => _perform(service, code, PetAction.pet)
                            : null,
                        child: AnimatedScale(
                          scale: _busyAction == null ? 1 : 1.06,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: pet.isSleeping ? .72 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              width: 190,
                              height: 190,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE8F2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withValues(alpha: .16),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/pets/dog_01.png',
                                fit: BoxFit.contain,
                                cacheWidth: 420,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _localReaction ?? pet.reaction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Stat(
                      label: 'Hambre',
                      value: pet.hunger,
                      color: Colors.orange,
                    ),
                    _Stat(
                      label: 'Felicidad',
                      value: pet.happiness,
                      color: Colors.pink,
                    ),
                    _Stat(
                      label: 'Energía',
                      value: pet.energy,
                      color: Colors.blue,
                    ),
                    _Stat(
                      label: 'Higiene',
                      value: pet.hygiene,
                      color: Colors.cyan,
                    ),
                    _Stat(
                      label: 'Necesidad de baño',
                      value: pet.toiletNeed,
                      color: Colors.brown,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 14,
                      runSpacing: 18,
                      children: [
                        _Action(
                          icon: Icons.restaurant,
                          label: 'Alimentar',
                          busy: _busyAction == PetAction.feed,
                          onTap: () => _perform(service, code, PetAction.feed),
                        ),
                        _Action(
                          icon: Icons.sports_tennis,
                          label: 'Jugar',
                          busy: _busyAction == PetAction.play,
                          onTap: () => _perform(service, code, PetAction.play),
                        ),
                        _Action(
                          icon: pet.isSleeping
                              ? Icons.wb_sunny_rounded
                              : Icons.bedtime,
                          label: pet.isSleeping ? 'Despertar' : 'Dormir',
                          busy:
                              _busyAction == PetAction.sleep ||
                              _busyAction == PetAction.wake,
                          onTap: () => _perform(
                            service,
                            code,
                            pet.isSleeping ? PetAction.wake : PetAction.sleep,
                          ),
                        ),
                        _Action(
                          icon: Icons.bathtub_rounded,
                          label: 'Bañar',
                          busy: _busyAction == PetAction.bathe,
                          onTap: () => _perform(service, code, PetAction.bathe),
                        ),
                        _Action(
                          icon: Icons.wc_rounded,
                          label: 'Ir al baño',
                          busy: _busyAction == PetAction.toilet,
                          onTap: () =>
                              _perform(service, code, PetAction.toilet),
                        ),
                        _Action(
                          icon: Icons.favorite_rounded,
                          label: 'Acariciar',
                          busy: _busyAction == PetAction.pet,
                          onTap: () => _perform(service, code, PetAction.pet),
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

  String _reactionFor(PetAction action) => switch (action) {
    PetAction.pet => '¡Más caricias! 💗',
    PetAction.feed => '¡Qué rico! 🍖',
    PetAction.play => '¡Vamos a jugar! 🎾',
    PetAction.sleep => 'Buenas noches… 💤',
    PetAction.wake => '¡Buenos días! ☀️',
    PetAction.bathe => '¡Burbujas! 🫧',
    PetAction.toilet => 'Ahora me siento más cómodo.',
  };
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
  const _Action({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    child: Column(
      children: [
        IconButton.filled(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}
