enum GardenItemAction { water, sit, none }

abstract final class GardenInteractionPolicy {
  static GardenItemAction actionForType(String type) {
    return switch (type) {
      'plant' ||
      'special_plant' ||
      'pot' ||
      'flowers' ||
      'bush' ||
      'tree' => GardenItemAction.water,
      'table' => GardenItemAction.sit,
      _ => GardenItemAction.none,
    };
  }

  static bool isWaterable(String type) {
    return actionForType(type) == GardenItemAction.water;
  }

  static String plantStageLabel(int stage) {
    return switch (stage.clamp(1, 3)) {
      1 => 'Brote',
      2 => 'Creciendo',
      _ => 'Floreció',
    };
  }
}
