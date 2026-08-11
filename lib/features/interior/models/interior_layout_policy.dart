import 'dart:ui';

enum InteriorZone { rest, living, dining, pawdo, decor }

abstract final class InteriorLayoutPolicy {
  static InteriorZone zoneForType(String type) {
    return switch (type) {
      'bed' => InteriorZone.rest,
      'sofa' || 'tv' || 'rug' => InteriorZone.living,
      'table' => InteriorZone.dining,
      'pet_bed' => InteriorZone.pawdo,
      _ => InteriorZone.decor,
    };
  }

  static String zoneLabel(String type) {
    return switch (zoneForType(type)) {
      InteriorZone.rest => 'Descanso',
      InteriorZone.living => 'Sala',
      InteriorZone.dining => 'Mesa',
      InteriorZone.pawdo => 'Rincón de Pawdo',
      InteriorZone.decor => 'Decoración',
    };
  }

  static Rect preferredBounds(String type) {
    return switch (zoneForType(type)) {
      InteriorZone.rest => const Rect.fromLTWH(250, 500, 420, 300),
      InteriorZone.living => const Rect.fromLTWH(620, 500, 500, 310),
      InteriorZone.dining => const Rect.fromLTWH(900, 590, 350, 220),
      InteriorZone.pawdo => const Rect.fromLTWH(1230, 625, 280, 180),
      InteriorZone.decor => const Rect.fromLTWH(1040, 470, 470, 330),
    };
  }
}
