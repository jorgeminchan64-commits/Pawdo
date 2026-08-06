import 'package:flutter/material.dart';

import '../../chat/screens/chat_screen.dart';
import '../../games/screens/games_hub_screen.dart';
import '../../missions/screens/daily_missions_screen.dart';
import '../../location/screens/location_sharing_screen.dart';
import '../../location/widgets/location_sharing_status_banner.dart';
import '../../pet/screens/pet_screen.dart';
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

  void _openWorld() {
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboardScreen(
        onOpenWorld: _openWorld,
        onOpenGames: () => _open(const GamesHubScreen()),
        onOpenMissions: () => _open(const DailyMissionsScreen()),
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
