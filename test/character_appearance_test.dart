import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/characters/models/character_appearance.dart';
import 'package:pawdo/features/characters/screens/character_editor_screen.dart';
import 'package:pawdo/features/characters/widgets/character_appearance_preview.dart';
import 'package:pawdo/features/profile/services/profile_service.dart';

void main() {
  test('appearance round-trips every supported customization field', () {
    const appearance = CharacterAppearance(
      baseStyle: CharacterBaseStyle.classicGirl,
      hairStyle: CharacterHairStyle.curls,
      hairColor: CharacterHairColor.copper,
      skinTone: CharacterSkinTone.deep,
      outfitStyle: CharacterOutfitStyle.elegant,
      outfitColor: CharacterOutfitColor.blue,
      shoes: CharacterShoes.boots,
      accessory: CharacterAccessory.glasses,
      expression: CharacterExpression.excited,
      pose: CharacterPose.wave,
    );

    final restored = CharacterAppearance.fromMap(appearance.toMap());

    expect(restored.toMap(), appearance.toMap());
  });

  test('appearance falls back safely from legacy or manipulated values', () {
    final appearance = CharacterAppearance.fromMap(<String, dynamic>{
      'baseStyle': 'unknown',
      'hairStyle': 42,
      'skinTone': 'invalid',
    });

    expect(appearance.baseStyle, CharacterBaseStyle.classicBoy);
    expect(appearance.hairStyle, CharacterHairStyle.short);
    expect(appearance.skinTone, CharacterSkinTone.warm);
  });

  testWidgets('editor previews and persists independent appearance choices', (
    tester,
  ) async {
    final repository = _FakeAppearanceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorScreen(
          initialAppearance: const CharacterAppearance(),
          repository: repository,
        ),
      ),
    );

    expect(find.byType(CharacterAppearancePreview), findsOneWidget);
    Future<void> selectChip(String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.scrollUntilVisible(
        chip,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(chip);
      await tester.pump();
    }

    await selectChip('Rizos');
    await selectChip('Profundo');
    await selectChip('Azul');
    await selectChip('Lentes');
    await selectChip('Saludando');
    await tester.tap(find.text('Guardar').first);
    await tester.pumpAndSettle();

    expect(repository.saved?.hairStyle, CharacterHairStyle.curls);
    expect(repository.saved?.skinTone, CharacterSkinTone.deep);
    expect(repository.saved?.outfitColor, CharacterOutfitColor.blue);
    expect(repository.saved?.accessory, CharacterAccessory.glasses);
    expect(repository.saved?.pose, CharacterPose.wave);
  });
}

class _FakeAppearanceRepository implements CharacterAppearanceRepository {
  CharacterAppearance? saved;

  @override
  Future<void> updateCharacterAppearance(CharacterAppearance appearance) async {
    saved = appearance;
  }
}
