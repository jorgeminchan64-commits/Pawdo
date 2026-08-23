import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/characters/models/character_appearance.dart';
import 'package:pawdo/features/world/components/actors/animated_actor_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders distinct production avatar combinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final actors = await tester.runAsync(_loadShowcaseActors);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const ValueKey('avatar_showcase'),
          child: ColoredBox(
            color: const Color(0xFFFFF4F8),
            child: CustomPaint(painter: _AvatarShowcasePainter(actors!)),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('avatar_showcase')),
      matchesGoldenFile('goldens/avatar_renderer_2_5d.png'),
    );
  });
}

Future<List<AnimatedActorComponent>> _loadShowcaseActors() async {
  final appearances = <CharacterAppearance>[
    const CharacterAppearance(
      hairColor: CharacterHairColor.black,
      skinTone: CharacterSkinTone.warm,
      outfitStyle: CharacterOutfitStyle.casual,
      outfitColor: CharacterOutfitColor.blue,
      shoes: CharacterShoes.sneakers,
      accessory: CharacterAccessory.glasses,
    ),
    const CharacterAppearance(
      baseStyle: CharacterBaseStyle.classicGirl,
      hairStyle: CharacterHairStyle.long,
      hairColor: CharacterHairColor.copper,
      skinTone: CharacterSkinTone.light,
      outfitStyle: CharacterOutfitStyle.elegant,
      outfitColor: CharacterOutfitColor.rose,
      shoes: CharacterShoes.boots,
      accessory: CharacterAccessory.heartPin,
    ),
    const CharacterAppearance(
      hairStyle: CharacterHairStyle.curls,
      hairColor: CharacterHairColor.blonde,
      skinTone: CharacterSkinTone.deep,
      outfitStyle: CharacterOutfitStyle.cozy,
      outfitColor: CharacterOutfitColor.green,
      shoes: CharacterShoes.boots,
    ),
    const CharacterAppearance(
      baseStyle: CharacterBaseStyle.classicGirl,
      hairStyle: CharacterHairStyle.curls,
      hairColor: CharacterHairColor.brown,
      skinTone: CharacterSkinTone.deep,
      outfitStyle: CharacterOutfitStyle.cozy,
      outfitColor: CharacterOutfitColor.plum,
      shoes: CharacterShoes.sneakers,
      accessory: CharacterAccessory.headband,
    ),
  ];

  final actors = <AnimatedActorComponent>[];
  for (final appearance in appearances) {
    final isGirl = appearance.baseStyle == CharacterBaseStyle.classicGirl;
    final prefix = isGirl ? 'avatar_girl' : 'avatar_boy';
    final loaded = await Future.wait([
      _loadImage('assets/images/avatars/${prefix}_pro_spritesheet.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_hair.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_skin.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_outfit.png'),
      _loadImage('assets/images/avatars/layers/${prefix}_shoes.png'),
    ]);
    final actor = AnimatedActorComponent(
      spriteSheet: loaded[0],
      startPosition: Vector2.zero(),
      size: Vector2(150, 270),
      spriteLayout: isGirl ? ActorSpriteLayout.girl : ActorSpriteLayout.boy,
      appearanceLayers: ActorAppearanceLayers(
        appearance: appearance,
        hairMask: loaded[1],
        skinMask: loaded[2],
        outfitMask: loaded[3],
        shoesMask: loaded[4],
      ),
    )..update(0);
    actors.add(actor);
  }
  return actors;
}

Future<ui.Image> _loadImage(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class _AvatarShowcasePainter extends CustomPainter {
  const _AvatarShowcasePainter(this.actors);

  final List<AnimatedActorComponent> actors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < actors.length; index++) {
      canvas.save();
      canvas.translate(25 + index * 195, 120);
      actors[index].render(canvas);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarShowcasePainter oldDelegate) => false;
}
