import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/interior/models/interior_interaction_policy.dart';
import 'package:pawdo/features/world/components/alpha_hit_mask.dart';
import 'package:pawdo/features/world/models/actor_facing_policy.dart';
import 'package:pawdo/features/world/models/garden_layout_policy.dart';

void main() {
  group('Phase 0 world hotfixes', () {
    test('left-authored actor sprites face every horizontal destination', () {
      for (var sample = 1; sample <= 100; sample++) {
        expect(
          ActorFacingPolicy.horizontalScaleX(sample.toDouble()),
          -1,
          reason: 'A rightward destination must mirror the left-facing sheet.',
        );
        expect(
          ActorFacingPolicy.horizontalScaleX(-sample.toDouble()),
          1,
          reason: 'A leftward destination must preserve the authored sheet.',
        );
      }
    });

    test('transparent pixels never count as object taps', () {
      final rgba = Uint8List.fromList(<int>[
        255,
        255,
        255,
        0,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        12,
        255,
        255,
        255,
        120,
      ]);
      final mask = AlphaHitMask.fromRgba(width: 2, height: 2, rgba: rgba);

      expect(mask.containsNormalized(0, 0), isFalse);
      expect(mask.containsNormalized(1, 0), isTrue);
      expect(mask.containsNormalized(0, 1), isFalse);
      expect(mask.containsNormalized(1, 1), isTrue);
      expect(mask.containsNormalized(-0.01, 0.5), isFalse);
      expect(mask.containsNormalized(1.01, 0.5), isFalse);
    });

    test('one hundred empty sprite taps produce zero hits', () {
      final rgba = Uint8List(10 * 10 * 4);
      rgba[(5 * 10 + 5) * 4 + 3] = 255;
      final mask = AlphaHitMask.fromRgba(width: 10, height: 10, rgba: rgba);

      for (var sample = 0; sample < 100; sample++) {
        final x = (sample % 50) / 49;
        final y = sample < 50 ? 0.0 : 1.0;
        expect(
          mask.containsNormalized(x, y),
          isFalse,
          reason: 'Transparent sample $sample must not hit an object.',
        );
      }
      expect(mask.containsNormalized(5 / 9, 5 / 9), isTrue);
    });

    test('garden objects are clamped fully inside safe scene bounds', () {
      const flowerSize = Size(320, 125);
      final clamped = GardenLayoutPolicy.clampCenter(
        const Offset(460, 900),
        flowerSize,
      );

      expect(clamped.dy, 757.5);
      expect(GardenLayoutPolicy.isInsideSafeArea(clamped, flowerSize), isTrue);
      expect(
        GardenLayoutPolicy.isInsideSafeArea(const Offset(200, 790), flowerSize),
        isFalse,
        reason: 'The edit-button safe zone cannot receive garden items.',
      );
      expect(
        GardenLayoutPolicy.isInsideSafeArea(
          const Offset(1580, 500),
          const Size(100, 100),
        ),
        isFalse,
        reason: 'The right navigation safe zone must remain unobstructed.',
      );
    });

    test('incorrect legacy bed animation remains disabled', () {
      expect(InteriorInteractionPolicy.allowsLegacyBedInteraction, isFalse);
    });
  });
}
