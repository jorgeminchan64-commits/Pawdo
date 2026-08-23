import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/characters/models/character_appearance.dart';
import 'package:pawdo/features/characters/widgets/character_appearance_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editor previews the same production 2.5D avatars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: ValueKey('character_preview_showcase'),
          child: ColoredBox(
            color: Color(0xFFFFF8FA),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CharacterAppearancePreview(
                  appearance: CharacterAppearance(
                    hairStyle: CharacterHairStyle.curls,
                    hairColor: CharacterHairColor.black,
                    skinTone: CharacterSkinTone.warm,
                    outfitStyle: CharacterOutfitStyle.cozy,
                    outfitColor: CharacterOutfitColor.blue,
                    accessory: CharacterAccessory.glasses,
                    expression: CharacterExpression.excited,
                    pose: CharacterPose.wave,
                  ),
                ),
                CharacterAppearancePreview(
                  appearance: CharacterAppearance(
                    baseStyle: CharacterBaseStyle.classicGirl,
                    hairStyle: CharacterHairStyle.long,
                    hairColor: CharacterHairColor.copper,
                    skinTone: CharacterSkinTone.deep,
                    outfitStyle: CharacterOutfitStyle.elegant,
                    outfitColor: CharacterOutfitColor.plum,
                    shoes: CharacterShoes.boots,
                    accessory: CharacterAccessory.heartPin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (
      var attempt = 0;
      attempt < 80 &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('character_preview_showcase')),
      matchesGoldenFile('goldens/character_preview_2_5d.png'),
    );
  });
}
