import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../characters/screens/character_editor_screen.dart';
import '../../economy/screens/economy_history_screen.dart';
import '../../profile/models/profile_data.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../shop/models/shop_catalog.dart';
import '../../shop/screens/garden_shop_screen.dart';
import '../../shop/screens/interior_shop_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, snapshot) {
        final raw = snapshot.data?.data();
        final profile = user == null || raw == null
            ? null
            : ProfileData.fromMap(<String, dynamic>{
                ...raw,
                'uid': user.uid,
                'email': user.email ?? raw['email'] ?? '',
              });
        return Scaffold(
          backgroundColor: const Color(0xFFFFF3FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFF3FA),
            elevation: 0,
            title: const Text(
              'Tienda Pawdo 🛍️',
              style: TextStyle(
                color: Color(0xFF74308D),
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Historial compartido',
                onPressed: () => _open(context, const EconomyHistoryScreen()),
                icon: const Icon(Icons.receipt_long_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
              children: [
                const _ShopIntro(),
                const SizedBox(height: 20),
                Text(
                  'Explora por categoría',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF602676),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cada artículo indica claramente cómo se obtiene.',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.62)),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shopCatalog.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 3 ? 1.35 : 0.96,
                      ),
                      itemBuilder: (context, index) {
                        final entry = shopCatalog[index];
                        return _CategoryCard(
                          entry: entry,
                          onTap: () => _openCategory(context, entry, profile),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                const _PremiumNotice(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCategory(
    BuildContext context,
    ShopCategoryEntry entry,
    ProfileData? profile,
  ) {
    switch (entry.destination) {
      case ShopDestination.character:
        if (profile == null) {
          _message(context, 'Espera un momento mientras cargamos tu perfil.');
          return;
        }
        _open(
          context,
          CharacterEditorScreen(initialAppearance: profile.characterAppearance),
        );
      case ShopDestination.interior:
        _open(context, const InteriorShopScreen());
      case ShopDestination.garden:
        _open(context, const GardenShopScreen());
      case ShopDestination.profile:
        if (profile == null) {
          _message(context, 'Espera un momento mientras cargamos tu perfil.');
          return;
        }
        _open(context, EditProfileScreen(profile: profile));
      case ShopDestination.unavailable:
        _message(
          context,
          'Esta categoría está bloqueada por ahora. No se realizará ningún cobro.',
        );
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShopIntro extends StatelessWidget {
  const _ShopIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF933EA9), Color(0xFFE15E92)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Haz que Pawdo se sienta suyo ✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Por ahora solo usamos opciones gratuitas y monedas de Pawdo. '
            'No hay compras con dinero real activas.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.entry, required this.onTap});

  final ShopCategoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (entry.access) {
      ShopAccess.free => (
        'Gratis',
        const Color(0xFF287A4B),
        Icons.check_circle_outline,
      ),
      ShopAccess.coins => (
        'Monedas',
        const Color(0xFF9A6414),
        Icons.paid_outlined,
      ),
      ShopAccess.locked => (
        'Bloqueado',
        const Color(0xFF68616C),
        Icons.lock_outline,
      ),
      ShopAccess.premiumFuture => (
        'Premium futuro',
        const Color(0xFF773D9A),
        Icons.workspace_premium_outlined,
      ),
    };
    return Semantics(
      button: true,
      label: '${entry.title}. $label. ${entry.subtitle}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.emoji, style: const TextStyle(fontSize: 30)),
                    Icon(icon, size: 19, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF602676),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumNotice extends StatelessWidget {
  const _PremiumNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E8F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9BFE8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_outlined, color: Color(0xFF773D9A)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Premium futuro: la tienda ya distingue contenido premium, pero '
              'permanece bloqueado hasta integrar y validar Google Play Billing.',
              style: TextStyle(color: Color(0xFF5B326E), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
