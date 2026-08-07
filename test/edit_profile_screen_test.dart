import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/profile/models/profile_data.dart';
import 'package:pawdo/features/profile/screens/edit_profile_screen.dart';
import 'package:pawdo/features/profile/services/profile_service.dart';

void main() {
  testWidgets('prefills and saves editable profile fields', (tester) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(profile: _profile(), repository: repository),
      ),
    );

    expect(find.text('Jorge'), findsOneWidget);
    expect(find.text('Jorgito'), findsOneWidget);
    expect(find.text('Pronto podrás editarlo'), findsNothing);

    final lavender = find.widgetWithText(ChoiceChip, 'Lavanda');
    await tester.drag(
      find.byKey(const ValueKey('edit_profile_form')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    await tester.tap(lavender);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved, isTrue);
    expect(repository.displayName, 'Jorgito');
    expect(repository.theme, ProfileTheme.lavender);
  });

  testWidgets('rejects an empty visible name', (tester) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(profile: _profile(), repository: repository),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Este campo es obligatorio'), findsOneWidget);
    expect(repository.saved, isFalse);
  });
}

ProfileData _profile() => ProfileData(
  uid: 'user-1',
  email: 'user@example.test',
  name: 'Jorge',
  displayName: 'Jorgito',
  birthday: DateTime(1995, 2, 3),
  relationshipStartDate: DateTime(2024, 6, 5),
  photoStoragePath: '',
  coupleCode: 'ABC123',
  theme: ProfileTheme.rose,
);

class _FakeProfileRepository implements ProfileRepository {
  bool saved = false;
  String? displayName;
  ProfileTheme? theme;

  @override
  Future<String> uploadProfilePhoto(File imageFile) async => 'unused';

  @override
  Future<void> updateProfile({
    required String name,
    required String displayName,
    required DateTime birthday,
    required DateTime relationshipStartDate,
    required ProfileTheme theme,
    String? photoStoragePath,
  }) async {
    saved = true;
    this.displayName = displayName;
    this.theme = theme;
  }
}
