import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/screens/auth_gate.dart';
import 'features/home/screens/main_screen.dart';
import 'core/services/presence_service.dart';
import 'core/services/notification_service.dart';
import 'features/couple/services/couple_service.dart';
import 'features/location/services/location_sharing_service.dart';
import 'core/theme/app_theme.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  LocationSharingService.instance.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: PawdoApp()));
  unawaited(
    NotificationService.instance.initialize(
      onForeground: (message) {
        final body =
            message.notification?.body ?? 'Tienes una novedad en Pawdo';
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(body), behavior: SnackBarBehavior.floating),
        );
      },
      onOpenChat: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rootNavigatorKey.currentState?.pushNamed('/chat');
        });
      },
    ),
  );
}

class PawdoApp extends StatefulWidget {
  const PawdoApp({super.key});

  @override
  State<PawdoApp> createState() => _PawdoAppState();
}

class _PawdoAppState extends State<PawdoApp> {
  late final PresenceService _presence;

  @override
  void initState() {
    super.initState();
    _presence = PresenceService(CoupleService())..start();
  }

  @override
  void dispose() {
    _presence.dispose();
    unawaited(LocationSharingService.instance.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Pawdo',
      theme: AppTheme.light,
      routes: {
        '/home': (_) => const MainScreen(),
        '/chat': (_) => const MainScreen(initialIndex: 2),
      },
      home: const AuthGate(),
    );
  }
}
