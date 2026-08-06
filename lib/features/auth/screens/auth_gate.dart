import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/android_widget_service.dart';
import '../../couple/screens/connect_screen.dart';
import '../../home/screens/main_screen.dart';
import '../../profile/screens/profile_setup_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error de autenticación')),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AndroidWidgetService.instance.clear();
          });
          return const WelcomeScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(includeMetadataChanges: true),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Error cargando perfil')),
              );
            }

            final data = userSnapshot.data?.data();
            final profileCompleted = data?['profileCompleted'] == true;
            final coupleCode = data?['coupleCode']?.toString() ?? '';
            final pendingCoupleCode =
                data?['pendingCoupleCode']?.toString() ?? '';

            // Do not change screens for a local optimistic write. Wait until
            // Firestore confirms it so a rejected profile cannot flash the
            // couple screen and then send the user backwards.
            if (userSnapshot.data?.metadata.hasPendingWrites == true) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!profileCompleted) {
              return const ProfileSetupScreen();
            }

            if (coupleCode.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AndroidWidgetService.instance.clear();
              });
              return ConnectScreen(existingCode: pendingCoupleCode);
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('couples')
                  .doc(coupleCode)
                  .snapshots(),
              builder: (context, coupleSnapshot) {
                if (coupleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final coupleData = coupleSnapshot.data?.data();
                final user1 = coupleData?['user1'];
                final user2 = coupleData?['user2'];
                final status = coupleData?['status']?.toString();
                final coupleComplete =
                    user1 != null &&
                    user2 != null &&
                    (status == null || status == 'paired');

                if (!coupleComplete) {
                  return ConnectScreen(existingCode: coupleCode);
                }

                return const MainScreen();
              },
            );
          },
        );
      },
    );
  }
}
