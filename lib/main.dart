import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/screens/auth_gate.dart';
import 'features/home/screens/main_screen.dart';
import 'core/services/presence_service.dart';
import 'core/services/app_check_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/network_recovery_service.dart';
import 'features/couple/services/couple_service.dart';
import 'features/location/services/location_sharing_service.dart';
import 'core/theme/app_theme.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded<void>(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = _recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _recordUnhandledError(error, stackTrace);
      return true;
    };
    runApp(const ProviderScope(child: PawdoBootstrap()));
  }, _recordUnhandledError);
}

void _recordFlutterError(FlutterErrorDetails details) {
  if (kDebugMode) {
    FlutterError.presentError(details);
    return;
  }
  debugPrint('Unhandled Flutter error: ${details.exception.runtimeType}');
}

void _recordUnhandledError(Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('Unhandled async error: $error\n$stackTrace');
    return;
  }
  debugPrint('Unhandled async error: ${error.runtimeType}');
}

Future<void> _initializePawdoServices() async {
  await Firebase.initializeApp();
  await AppCheckService().activate();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NetworkRecoveryService.instance.start();
  LocationSharingService.instance.initialize();
  await NotificationService.instance.initialize(
    onForeground: (message) {
      final body = message.notification?.body ?? 'Tienes una novedad en Pawdo';
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(body), behavior: SnackBarBehavior.floating),
      );
    },
    onOpenChat: (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootNavigatorKey.currentState?.pushNamed('/chat');
      });
    },
  );
}

enum _BootstrapStatus { loading, ready, failed }

class PawdoBootstrap extends StatefulWidget {
  const PawdoBootstrap({
    super.key,
    this.initialize,
    this.appBuilder,
    this.onInitializationError,
  });

  final Future<void> Function()? initialize;
  final WidgetBuilder? appBuilder;
  final void Function(Object error, StackTrace stackTrace)?
  onInitializationError;

  @override
  State<PawdoBootstrap> createState() => _PawdoBootstrapState();
}

class _PawdoBootstrapState extends State<PawdoBootstrap> {
  _BootstrapStatus _status = _BootstrapStatus.loading;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await (widget.initialize ?? _initializePawdoServices)();
      if (mounted) setState(() => _status = _BootstrapStatus.ready);
    } catch (error, stackTrace) {
      (widget.onInitializationError ?? _recordUnhandledError)(
        error,
        stackTrace,
      );
      if (mounted) setState(() => _status = _BootstrapStatus.failed);
    }
  }

  void _retry() {
    setState(() => _status = _BootstrapStatus.loading);
    unawaited(_initialize());
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _BootstrapStatus.ready:
        return (widget.appBuilder ?? (_) => const PawdoApp())(context);
      case _BootstrapStatus.failed:
        return _BootstrapFailureApp(onRetry: _retry);
      case _BootstrapStatus.loading:
        return const _BootstrapLoadingApp();
    }
  }
}

class _BootstrapLoadingApp extends StatelessWidget {
  const _BootstrapLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Semantics(
            label: 'Iniciando Pawdo',
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'No pudimos iniciar Pawdo',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Revisa tu conexión e inténtalo nuevamente.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PawdoApp extends StatefulWidget {
  const PawdoApp({super.key});

  @override
  State<PawdoApp> createState() => _PawdoAppState();
}

class _PawdoAppState extends State<PawdoApp> {
  late final PresenceService _presence;
  late final VoidCallback _unregisterRecovery;

  @override
  void initState() {
    super.initState();
    _presence = PresenceService(CoupleService())..start();
    _unregisterRecovery = NetworkRecoveryService.instance.registerRecoveryTask(
      'core-services',
      () async {
        await _presence.recover();
        await NotificationService.instance.recover();
        await LocationSharingService.instance.recover();
      },
    );
  }

  @override
  void dispose() {
    _unregisterRecovery();
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
