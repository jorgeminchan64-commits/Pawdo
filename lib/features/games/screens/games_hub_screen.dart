import 'package:flutter/material.dart';

import '../catch_pawdo/screens/catch_pawdo_screen.dart';
import '../ludo/screens/ludo_screen.dart';
import '../memory/screens/couple_memory_screen.dart';
import '../movie_guess/screens/movie_guess_screen.dart';
import '../offline/screens/offline_memory_screen.dart';
import '../offline/screens/offline_tic_tac_toe_screen.dart';
import '../questions/screens/couple_questions_screen.dart';
import '../roulette/screens/challenge_roulette_screen.dart';
import '../rps/screens/rock_paper_scissors_screen.dart';
import '../tic_tac_toe/screens/tic_tac_toe_screen.dart';

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3FA),
        elevation: 0,
        title: const Text(
          'Juegos Pawdo 🎮',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.wifi,
            title: 'Jugar con tu pareja',
            subtitle: 'Requiere internet · recompensas diarias del servidor',
          ),
          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '🎲',
            title: 'Ludo Pawdo',
            subtitle: 'Juega por turnos con tu pareja y gana recompensas.',
            badge: 'Disponible',
            available: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LudoScreen()),
              );
            },
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '💘',
            title: 'Preguntas de pareja',
            subtitle: 'Preguntas bonitas para conocerse más.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const CoupleQuestionsScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '🎡',
            title: 'Ruleta de retos',
            subtitle: 'Gira la ruleta y cumple retos románticos.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const ChallengeRouletteScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '🧠',
            title: 'Memoria de pareja',
            subtitle: 'Encuentren cartas iguales y ganen monedas.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const CoupleMemoryScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '⭕',
            title: 'Tres en raya',
            subtitle: 'Juego rápido para competir en pareja.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const TicTacToeScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '✊',
            title: 'Piedra, papel o tijera',
            subtitle: 'Mini juego rápido con recompensas.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const RockPaperScissorsScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '🐶',
            title: 'Atrapa a Pawdo',
            subtitle: 'Un mini juego divertido con tu mascota.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const CatchPawdoScreen()),
          ),

          const SizedBox(height: 12),

          _gameCard(
            context: context,
            emoji: '🎬',
            title: 'Adivina la película',
            subtitle: 'Juego de pistas para jugar mientras ven cine.',
            badge: 'Disponible',
            available: true,
            onTap: () => _open(context, const MovieGuessScreen()),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.cloud_off,
            title: 'Jugar sin conexión',
            subtitle: 'Disponible sin internet · nunca entrega recompensas',
          ),
          const SizedBox(height: 12),
          _gameCard(
            context: context,
            emoji: '🧠',
            title: 'Memoria offline',
            subtitle: 'Encuentra las 8 parejas desde este teléfono.',
            badge: 'Offline',
            available: true,
            onTap: () => _open(context, const OfflineMemoryScreen()),
          ),
          const SizedBox(height: 12),
          _gameCard(
            context: context,
            emoji: '⭕',
            title: 'Tres en raya vs Pawdo',
            subtitle: 'Compite contra una IA simple sin usar internet.',
            badge: 'Offline',
            available: true,
            onTap: () => _open(context, const OfflineTicTacToeScreen()),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6EA), Color(0xFFEED7FF)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Text('🎮', style: TextStyle(fontSize: 46)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Centro de juegos para jugar con tu pareja dentro de Pawdo.',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard({
    required BuildContext context,
    required String emoji,
    required String title,
    required String subtitle,
    required String badge,
    required bool available,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: available
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title estará disponible pronto 🔒')),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: available
                      ? const Color(0xFFFFEEF8)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: available ? Colors.purple : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: available
                                ? Colors.green.shade50
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: available ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                available ? Icons.arrow_forward_ios : Icons.lock,
                color: available ? Colors.purple : Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.58),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
