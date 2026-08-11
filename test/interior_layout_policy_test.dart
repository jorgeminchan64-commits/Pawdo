import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/interior/models/interior_layout_policy.dart';

void main() {
  group('InteriorLayoutPolicy', () {
    test('assigns functional furniture to coherent room zones', () {
      expect(InteriorLayoutPolicy.zoneForType('bed'), InteriorZone.rest);
      expect(InteriorLayoutPolicy.zoneForType('sofa'), InteriorZone.living);
      expect(InteriorLayoutPolicy.zoneForType('tv'), InteriorZone.living);
      expect(InteriorLayoutPolicy.zoneForType('table'), InteriorZone.dining);
      expect(InteriorLayoutPolicy.zoneForType('pet_bed'), InteriorZone.pawdo);
      expect(InteriorLayoutPolicy.zoneForType('plant'), InteriorZone.decor);
    });

    test('keeps every preferred zone inside the room bounds', () {
      for (final type in <String>[
        'bed',
        'sofa',
        'tv',
        'rug',
        'table',
        'pet_bed',
        'plant',
        'lamp',
      ]) {
        final bounds = InteriorLayoutPolicy.preferredBounds(type);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(1800));
        expect(bounds.bottom, lessThanOrEqualTo(900));
      }
    });

    test('provides user-facing labels for placement feedback', () {
      expect(InteriorLayoutPolicy.zoneLabel('bed'), 'Descanso');
      expect(InteriorLayoutPolicy.zoneLabel('sofa'), 'Sala');
      expect(InteriorLayoutPolicy.zoneLabel('table'), 'Mesa');
      expect(InteriorLayoutPolicy.zoneLabel('pet_bed'), 'Rincón de Pawdo');
      expect(InteriorLayoutPolicy.zoneLabel('lamp'), 'Decoración');
    });
  });
}
