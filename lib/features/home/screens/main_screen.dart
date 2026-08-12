import 'package:flutter/material.dart';

import '../../../core/widgets/network_status_banner.dart';
import '../../chat/screens/chat_screen.dart';
import '../../calendar/screens/couple_calendar_screen.dart';
import '../../games/screens/games_hub_screen.dart';
import '../../interior/screens/pawdo_interior_screen.dart';
import '../../missions/screens/daily_missions_screen.dart';
import '../../location/screens/location_sharing_screen.dart';
import '../../location/widgets/location_sharing_status_banner.dart';
import '../../memories/screens/memory_album_screen.dart';
import '../../pet/screens/pet_screen.dart';
import '../../relationship/screens/relationship_counter_screen.dart';
import '../../world/screens/world_screen.dart';
import 'home_dashboard_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, 4);
  }

  void changeTab(int newIndex) => setState(() => index = newIndex);

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openGarden() {
    _open(
      WorldScreen(
        onNavigate: (legacyIndex) {
          Navigator.of(context).pop();
          if (legacyIndex == 4) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _open(const DailyMissionsScreen()),
            );
            return;
          }
          changeTab(legacyIndex == 5 ? 4 : legacyIndex.clamp(0, 4));
        },
      ),
    );
  }

  void _openHouse() => _open(const PawdoInteriorScreen());

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboardScreen(
        onOpenHouse: _openHouse,
        onOpenGarden: _openGarden,
        onOpenGames: () => _open(const GamesHubScreen()),
        onOpenMissions: () => _open(const DailyMissionsScreen()),
        onOpenAlbum: () => _open(const MemoryAlbumScreen()),
        onOpenCalendar: () => _open(const CoupleCalendarScreen()),
        onOpenRelationship: (code) =>
            _open(RelationshipCounterScreen(coupleCode: code)),
        onNavigate: changeTab,
      ),
      const PetScreen(),
      const ChatScreen(),
      const ShopScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NetworkStatusBanner(),
          LocationSharingStatusBanner(
            onOpen: () => _open(const LocationSharingScreen()),
          ),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: changeTab,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.pets_outlined),
                selectedIcon: Icon(Icons.pets_rounded),
                label: 'Mascota',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Tienda',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
