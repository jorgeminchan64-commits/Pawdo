import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/world/models/garden_interaction_policy.dart';

void main() {
  group('GardenInteractionPolicy', () {
    test('waters only explicitly interactive plants', () {
      for (final type in <String>['plant', 'special_plant', 'pot']) {
        expect(
          GardenInteractionPolicy.actionForType(type),
          GardenItemAction.water,
        );
      }

      expect(
        GardenInteractionPolicy.actionForType('table'),
        GardenItemAction.sit,
      );
      expect(
        GardenInteractionPolicy.actionForType('empty'),
        GardenItemAction.none,
      );
      expect(
        GardenInteractionPolicy.actionForType('house'),
        GardenItemAction.none,
      );
      for (final decorativeType in <String>['flowers', 'bush', 'tree']) {
        expect(
          GardenInteractionPolicy.actionForType(decorativeType),
          GardenItemAction.none,
        );
      }
    });

    test('uses clear labels for the three persisted plant stages', () {
      expect(GardenInteractionPolicy.plantStageLabel(1), 'Brote');
      expect(GardenInteractionPolicy.plantStageLabel(2), 'Creciendo');
      expect(GardenInteractionPolicy.plantStageLabel(3), 'Floreció');
      expect(GardenInteractionPolicy.plantStageLabel(99), 'Floreció');
    });
  });
}
