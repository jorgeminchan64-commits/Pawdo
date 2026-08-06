import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/android_widget_service.dart';
import '../../couple/services/couple_service.dart';
import '../../settings/screens/notification_preferences_screen.dart';
import '../../settings/screens/widget_privacy_screen.dart';
import '../../wellness/screens/wellness_screen.dart';
import '../../location/screens/location_sharing_screen.dart';
import '../../location/services/location_sharing_service.dart';
import '../../calls/screens/call_readiness_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> logout() async {
    try {
      await LocationSharingService().stop();
    } catch (_) {
      // El cierre de sesión continúa; la sesión también vence en servidor.
    }
    await NotificationService.instance.unregisterBeforeLogout();
    await AndroidWidgetService.instance.clear();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> unlinkCouple(BuildContext context) async {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      appBar: AppBar(
        title: const Text("Perfil 👤"),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 25),

          const CircleAvatar(
            radius: 55,
            backgroundColor: Color(0xFF6C63FF),
            child: Icon(Icons.person, size: 65, color: Colors.white),
          ),

          const SizedBox(height: 20),

          Text(
            user?.email ?? "Usuario Pawdo",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            "Mi cuenta Pawdo ❤️",
            style: TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 35),

          _profileCard(
            icon: Icons.cake,
            title: "Cumpleaños",
            subtitle: "Pronto podrás editarlo",
          ),

          _profileCard(
            icon: Icons.favorite,
            title: "Relación",
            subtitle: "Datos de pareja conectados",
          ),

          _profileCard(
            icon: Icons.home,
            title: "Casa",
            subtitle: "Casa virtual compartida",
          ),

          _profileCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notificaciones y privacidad',
            subtitle: 'Permisos, vistas previas y horario silencioso',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen(),
              ),
            ),
          ),

          _profileCard(
            icon: Icons.favorite_outline,
            title: 'Ciclo y bienestar',
            subtitle: 'Módulo opcional, privado y bajo tu control',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WellnessScreen())),
          ),

          _profileCard(
            icon: Icons.widgets_outlined,
            title: 'Widget de Android',
            subtitle: 'Estado cacheado y privacidad de pantalla principal',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WidgetPrivacyScreen()),
            ),
          ),

          _profileCard(
            icon: Icons.location_on_outlined,
            title: 'Ubicación temporal',
            subtitle: 'Puntual, aproximada o por tiempo limitado',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationSharingScreen()),
            ),
          ),

          _profileCard(
            icon: Icons.video_call_outlined,
            title: 'Preparación de llamadas',
            subtitle: 'Comprobar privacidad, cámara y micrófono',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CallReadinessScreen()),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => unlinkCouple(context),
              icon: const Icon(Icons.link_off),
              label: const Text('Desvincular pareja'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: logout,
              icon: const Icon(Icons.logout),
              label: const Text(
                "Cerrar sesión",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF6C63FF), size: 30),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
