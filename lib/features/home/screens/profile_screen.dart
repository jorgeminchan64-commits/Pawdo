import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/android_widget_service.dart';
import '../../../core/services/notification_service.dart';
import '../../calls/screens/call_readiness_screen.dart';
import '../../couple/services/couple_service.dart';
import '../../location/screens/location_sharing_screen.dart';
import '../../location/services/location_sharing_service.dart';
import '../../profile/models/profile_data.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../profile/widgets/profile_avatar.dart';
import '../../settings/screens/notification_preferences_screen.dart';
import '../../settings/screens/widget_privacy_screen.dart';
import '../../wellness/screens/wellness_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout() async {
    try {
      await LocationSharingService().stop();
    } catch (_) {
      // El cierre de sesión continúa; la sesión también vence en servidor.
    }
    await NotificationService.instance.unregisterBeforeLogout();
    await AndroidWidgetService.instance.clear();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _unlinkCouple(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desvincular pareja'),
        content: const Text(
          'Ambos perderán el acceso inmediato a los datos compartidos. '
          'La información quedará archivada y no se borrará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      try {
        await LocationSharingService().stop();
      } catch (_) {
        // unlinkCouple elimina la ubicación compartida de ambos miembros.
      }
      await CoupleService().unlinkCouple();
      await AndroidWidgetService.instance.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La pareja fue desvinculada.')),
      );
    } on CoupleException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sesión no disponible')));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('No se pudo cargar tu perfil.')),
          );
        }
        final raw = snapshot.data?.data() ?? const <String, dynamic>{};
        final profile = ProfileData.fromMap(<String, dynamic>{
          ...raw,
          'uid': user.uid,
          'email': raw['email'] ?? user.email ?? '',
        });
        return _ProfileBody(
          profile: profile,
          cached: snapshot.data?.metadata.isFromCache == true,
          onLogout: _logout,
          onUnlink: () => _unlinkCouple(context),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.cached,
    required this.onLogout,
    required this.onUnlink,
  });

  final ProfileData profile;
  final bool cached;
  final Future<void> Function() onLogout;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        title: const Text('Tu perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (cached)
              const _InfoBanner(
                icon: Icons.cloud_off_outlined,
                text:
                    'Mostrando el perfil guardado mientras vuelve la conexión.',
              ),
            _ProfileHeader(profile: profile),
            const SizedBox(height: 14),
            _RelationshipPanel(profile: profile),
            if (profile.coupleCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PartnerCard(profile: profile),
            ],
            const SizedBox(height: 22),
            const _SectionTitle('Personalización'),
            _ProfileTile(
              icon: Icons.palette_outlined,
              title: 'Editar perfil y estilo',
              subtitle: 'Nombre, foto, fechas y fondo',
              onTap: () => _openEditor(context),
            ),
            const _SectionTitle('Conexión y bienestar'),
            _ProfileTile(
              icon: Icons.notifications_active_outlined,
              title: 'Notificaciones',
              subtitle: 'Vistas previas y horario silencioso',
              onTap: () =>
                  _open(context, const NotificationPreferencesScreen()),
            ),
            _ProfileTile(
              icon: Icons.favorite_outline,
              title: 'Ciclo y bienestar',
              subtitle: 'Módulo opcional y bajo tu control',
              onTap: () => _open(context, const WellnessScreen()),
            ),
            _ProfileTile(
              icon: Icons.location_on_outlined,
              title: 'Ubicación temporal',
              subtitle: 'Compartir de forma puntual o limitada',
              onTap: () => _open(context, const LocationSharingScreen()),
            ),
            const _SectionTitle('Dispositivo'),
            _ProfileTile(
              icon: Icons.widgets_outlined,
              title: 'Widget de Android',
              subtitle: 'Contenido visible y privacidad',
              onTap: () => _open(context, const WidgetPrivacyScreen()),
            ),
            _ProfileTile(
              icon: Icons.video_call_outlined,
              title: 'Llamadas',
              subtitle: 'En desarrollo · revisa cámara y micrófono',
              onTap: () => _open(context, const CallReadinessScreen()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onUnlink,
              icon: const Icon(Icons.link_off),
              label: const Text('Desvincular pareja'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onLogout,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8F2949),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context) {
    _open(context, EditProfileScreen(profile: profile));
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final colors = switch (profile.theme) {
      ProfileTheme.rose => const [Color(0xFFF06B9A), Color(0xFF9A55C7)],
      ProfileTheme.lavender => const [Color(0xFF7067CF), Color(0xFFB27AC8)],
      ProfileTheme.sunset => const [Color(0xFFF08A72), Color(0xFFC6538C)],
    };
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ProfileAvatar(
            key: ValueKey(
              'profile_${profile.photoStoragePath}_${profile.revision}',
            ),
            radius: 54,
            storagePath: profile.photoStoragePath,
          ),
          const SizedBox(height: 14),
          Text(
            profile.greetingName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (profile.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelationshipPanel extends StatelessWidget {
  const _RelationshipPanel({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final days = profile.daysTogether(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuestra historia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.favorite_rounded,
                  value: profile.relationshipStartDate == null ? '—' : '$days',
                  label: 'días juntos',
                ),
              ),
              Expanded(
                child: _Metric(
                  icon: Icons.event_available_outlined,
                  value: formatProfileDate(profile.relationshipStartDate),
                  label: 'desde',
                ),
              ),
              Expanded(
                child: _Metric(
                  icon: Icons.cake_outlined,
                  value: formatProfileDate(profile.birthday),
                  label: 'cumpleaños',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(profile.coupleCode)
          .snapshots(),
      builder: (context, snapshot) {
        final couple = snapshot.data?.data() ?? const <String, dynamic>{};
        final firstUid = couple['user1']?.toString() ?? '';
        final secondUid = couple['user2']?.toString() ?? '';
        final partnerUid = firstUid == profile.uid ? secondUid : firstUid;
        final profiles = couple['memberProfiles'] is Map
            ? Map<String, dynamic>.from(couple['memberProfiles'] as Map)
            : const <String, dynamic>{};
        final partner = profiles[partnerUid] is Map
            ? Map<String, dynamic>.from(profiles[partnerUid] as Map)
            : const <String, dynamic>{};
        final name = partner['name']?.toString().trim() ?? '';
        final photo = partner['photoStoragePath']?.toString();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFECF5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              ProfileAvatar(
                key: ValueKey(
                  'partner_${photo ?? ''}_${couple['memberProfilesUpdatedAt']}',
                ),
                radius: 28,
                storagePath: photo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu pareja',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      name.isEmpty ? 'Perfil conectado' : name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Color(0xFFC64279)),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFC64279)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE8F3),
          child: Icon(icon, color: const Color(0xFF8F3567)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE8B7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
