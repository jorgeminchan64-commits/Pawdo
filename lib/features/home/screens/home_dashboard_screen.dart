import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/android_widget_service.dart';
import '../../couple/services/couple_service.dart';
import '../models/home_dashboard_summary.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenHouse,
    required this.onOpenGarden,
    required this.onOpenGames,
    required this.onOpenMissions,
    required this.onOpenAlbum,
    required this.onOpenCalendar,
    required this.onOpenRelationship,
    required this.onNavigate,
  });

  final VoidCallback onOpenHouse;
  final VoidCallback onOpenGarden;
  final VoidCallback onOpenGames;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenAlbum;
  final VoidCallback onOpenCalendar;
  final ValueChanged<String> onOpenRelationship;
  final ValueChanged<int> onNavigate;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _profileRefreshRequested = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final profile = userSnapshot.data?.data() ?? const <String, dynamic>{};
        final code = profile['coupleCode']?.toString() ?? '';
        if (code.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AndroidWidgetService.instance.clear();
          });
          return _NotPaired(profile: profile);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('couples')
              .doc(code)
              .snapshots(),
          builder: (context, coupleSnapshot) {
            final couple =
                coupleSnapshot.data?.data() ?? const <String, dynamic>{};
            final memberProfiles = _map(couple['memberProfiles']);
            if (memberProfiles.isEmpty && !_profileRefreshRequested) {
              _profileRefreshRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                CoupleService().refreshCoupleProfiles().catchError((_) {});
              });
            }
            return _DashboardContent(
              uid: user.uid,
              coupleCode: code,
              ownProfile: profile,
              couple: couple,
              memberProfiles: memberProfiles,
              onOpenHouse: widget.onOpenHouse,
              onOpenGarden: widget.onOpenGarden,
              onOpenGames: widget.onOpenGames,
              onOpenMissions: widget.onOpenMissions,
              onOpenAlbum: widget.onOpenAlbum,
              onOpenCalendar: widget.onOpenCalendar,
              onOpenRelationship: widget.onOpenRelationship,
              onNavigate: widget.onNavigate,
            );
          },
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.uid,
    required this.coupleCode,
    required this.ownProfile,
    required this.couple,
    required this.memberProfiles,
    required this.onOpenHouse,
    required this.onOpenGarden,
    required this.onOpenGames,
    required this.onOpenMissions,
    required this.onOpenAlbum,
    required this.onOpenCalendar,
    required this.onOpenRelationship,
    required this.onNavigate,
  });

  final String uid;
  final String coupleCode;
  final Map<String, dynamic> ownProfile;
  final Map<String, dynamic> couple;
  final Map<String, dynamic> memberProfiles;
  final VoidCallback onOpenHouse;
  final VoidCallback onOpenGarden;
  final VoidCallback onOpenGames;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenAlbum;
  final VoidCallback onOpenCalendar;
  final ValueChanged<String> onOpenRelationship;
  final ValueChanged<int> onNavigate;

  int _number(String key, int fallback) =>
      (couple[key] as num?)?.round() ?? fallback;

  @override
  Widget build(BuildContext context) {
    final firstUid = couple['user1']?.toString() ?? '';
    final secondUid = couple['user2']?.toString() ?? '';
    final partnerUid = firstUid == uid ? secondUid : firstUid;
    final ownSummary = _map(memberProfiles[uid]);
    final partnerSummary = _map(memberProfiles[partnerUid]);
    final presence = _map(couple['memberPresence']);
    final ownName =
        (ownSummary['displayName'] ??
                ownSummary['name'] ??
                ownProfile['displayName'] ??
                ownProfile['name'] ??
                'Tú')
            .toString();
    final partnerName =
        (partnerSummary['displayName'] ?? partnerSummary['name'] ?? 'Tu pareja')
            .toString();
    final relationship = relationshipSummary(
      _readDate(couple['relationshipStartDate']) ??
          _readDate(ownProfile['relationshipStartDate']),
      DateTime.now(),
    );
    final streak = (_map(couple['dailyChest'])['streak'] as num?)?.round() ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AndroidWidgetService.instance.updateDashboard(
        energy: _number('energy', 70),
        streak: streak,
        lastActivity: couple['lastAction']?.toString(),
      );
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        gradient: _dashboardGradient(ownProfile['profileTheme']?.toString()),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.list(
                children: [
                  _TopBar(name: ownName),
                  const SizedBox(height: 14),
                  _CoupleCard(
                    ownName: ownName,
                    ownPhoto:
                        (ownSummary['photoStoragePath'] ??
                                ownProfile['photoStoragePath'])
                            ?.toString(),
                    ownOnline: _presenceIsFresh(
                      _map(presence[uid]),
                      fallbackOnline: ownProfile['online'] == true,
                      fallbackLastSeen: ownProfile['lastSeenAt'],
                    ),
                    partnerName: partnerName,
                    partnerPhoto: partnerSummary['photoStoragePath']
                        ?.toString(),
                    partnerOnline: _presenceIsFresh(_map(presence[partnerUid])),
                  ),
                  const SizedBox(height: 14),
                  _RelationshipCard(
                    summary: relationship,
                    onTap: () => onOpenRelationship(coupleCode),
                  ),
                  const SizedBox(height: 14),
                  _PetCard(
                    onTap: () => onNavigate(1),
                    energy: _number('energy', 70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.favorite_rounded,
                          label: 'Amor',
                          value: '${_number('love', 80)}',
                          color: const Color(0xFFE75A8C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          icon: Icons.bolt_rounded,
                          label: 'Energía',
                          value: '${_number('energy', 70)}',
                          color: const Color(0xFFF0A83D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          icon: Icons.monetization_on_rounded,
                          label: 'Monedas',
                          value: '${_number('coins', 0)}',
                          color: const Color(0xFFD48A12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Racha',
                          value: '$streak',
                          color: const Color(0xFFE56A46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Explorar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width < 370
                        ? 3
                        : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .92,
                    children: [
                      _Shortcut(Icons.home_rounded, 'Casa', onOpenHouse),
                      _Shortcut(Icons.yard_rounded, 'Jardín', onOpenGarden),
                      _Shortcut(
                        Icons.chat_bubble_rounded,
                        'Chat',
                        () => onNavigate(2),
                      ),
                      _Shortcut(
                        Icons.sports_esports_rounded,
                        'Juegos',
                        onOpenGames,
                      ),
                      _Shortcut(
                        Icons.storefront_rounded,
                        'Tienda',
                        () => onNavigate(3),
                      ),
                      _Shortcut(
                        Icons.card_giftcard_rounded,
                        'Recompensas',
                        onOpenMissions,
                      ),
                      _Shortcut(
                        Icons.photo_album_rounded,
                        'Álbum',
                        onOpenAlbum,
                      ),
                      _Shortcut(
                        Icons.calendar_month_rounded,
                        'Calendario',
                        onOpenCalendar,
                      ),
                      _Shortcut(
                        Icons.settings_rounded,
                        'Ajustes',
                        () => onNavigate(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ActivityCard(text: couple['lastAction']?.toString()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.asset(
          'assets/images/ui/pawdo_brand_master.png',
          width: 44,
          height: 44,
          cacheWidth: 120,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greetingForHour(_now.hour),
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
      Semantics(
        label: 'Hora actual ${formatDashboardClock(_now)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            formatDashboardClock(_now),
            style: const TextStyle(
              color: AppTheme.plum,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.summary, required this.onTap});

  final RelationshipSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.plum,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24743B83),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.durationLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.nextMomentLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoupleCard extends StatelessWidget {
  const _CoupleCard({
    required this.ownName,
    required this.ownPhoto,
    required this.ownOnline,
    required this.partnerName,
    required this.partnerPhoto,
    required this.partnerOnline,
  });
  final String ownName;
  final String? ownPhoto;
  final bool ownOnline;
  final String partnerName;
  final String? partnerPhoto;
  final bool partnerOnline;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE5EF), Color(0xFFEFE3FA)],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        Expanded(
          child: _Member(name: ownName, path: ownPhoto, online: ownOnline),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_rounded, color: Color(0xFFE75A8C)),
        ),
        Expanded(
          child: _Member(
            name: partnerName,
            path: partnerPhoto,
            online: partnerOnline,
          ),
        ),
      ],
    ),
  );
}

class _Member extends StatelessWidget {
  const _Member({required this.name, required this.path, required this.online});
  final String name;
  final String? path;
  final bool online;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          _StorageAvatar(path: path),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF36B777) : Colors.grey.shade400,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      Text(
        online ? 'En línea' : 'Desconectado',
        style: TextStyle(
          fontSize: 11,
          color: online ? const Color(0xFF27845A) : Colors.black45,
        ),
      ),
    ],
  );
}

class _StorageAvatar extends StatelessWidget {
  const _StorageAvatar({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) return _fallback();
    return FutureBuilder(
      future: FirebaseStorage.instance.ref(path).getData(1024 * 1024),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _fallback();
        return CircleAvatar(
          radius: 31,
          backgroundColor: Colors.white,
          backgroundImage: MemoryImage(snapshot.data!),
        );
      },
    );
  }

  Widget _fallback() => const CircleAvatar(
    radius: 31,
    backgroundColor: Colors.white,
    child: Icon(Icons.person_rounded, color: AppTheme.plum, size: 32),
  );
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.onTap, required this.energy});
  final VoidCallback onTap;
  final int energy;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Image.asset(
              'assets/images/pets/dog_01.png',
              width: 82,
              height: 82,
              fit: BoxFit.contain,
              cacheWidth: 240,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pawdo está esperando',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Energía compartida: $energy%',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(fontSize: 9.5, color: Colors.black54),
        ),
      ],
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.plum, size: 27),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.lavender,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: AppTheme.plum),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Actividad reciente',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                text?.isNotEmpty == true
                    ? text!
                    : 'Empiecen una actividad juntos',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NotPaired extends StatelessWidget {
  const _NotPaired({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ui/pawdo_brand_master.png',
              width: 130,
              cacheWidth: 300,
            ),
            const SizedBox(height: 18),
            Text(
              'Hola, ${profile['name'] ?? 'bienvenido'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conecta a tu pareja desde Perfil para abrir su espacio compartido.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

bool _presenceIsFresh(
  Map<String, dynamic> presence, {
  bool fallbackOnline = false,
  dynamic fallbackLastSeen,
}) {
  final online = presence['online'] == true || fallbackOnline;
  if (!online) return false;
  final raw = presence['lastSeenAt'] ?? fallbackLastSeen;
  final lastSeen = raw is Timestamp ? raw.toDate() : null;
  return lastSeen != null &&
      DateTime.now().difference(lastSeen) <= const Duration(minutes: 3);
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

LinearGradient _dashboardGradient(String? theme) {
  switch (theme) {
    case 'lavender':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4ECFB), Color(0xFFFFF8FB)],
      );
    case 'sunset':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE9DF), Color(0xFFFFF8FB)],
      );
    default:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEAF2), Color(0xFFFFF8FB)],
      );
  }
}
