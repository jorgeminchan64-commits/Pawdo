enum Pawdo3DScene {
  pet('pet'),
  garden('garden'),
  interior('interior');

  const Pawdo3DScene(this.wireName);

  final String wireName;
}

class Pawdo3DFeaturePolicy {
  const Pawdo3DFeaturePolicy({
    required this.masterEnabled,
    required this.androidRuntime,
    required this.enabledScenes,
  });

  factory Pawdo3DFeaturePolicy.fromEnvironment({required bool androidRuntime}) {
    const masterEnabled = bool.fromEnvironment(
      'PAWDO_UNITY_3D',
      defaultValue: false,
    );
    const petEnabled = bool.fromEnvironment(
      'PAWDO_UNITY_PET_3D',
      defaultValue: false,
    );
    const gardenEnabled = bool.fromEnvironment(
      'PAWDO_UNITY_GARDEN_3D',
      defaultValue: true,
    );
    const interiorEnabled = bool.fromEnvironment(
      'PAWDO_UNITY_INTERIOR_3D',
      defaultValue: true,
    );
    return Pawdo3DFeaturePolicy(
      masterEnabled: masterEnabled,
      androidRuntime: androidRuntime,
      enabledScenes: {
        if (petEnabled) Pawdo3DScene.pet,
        if (gardenEnabled) Pawdo3DScene.garden,
        if (interiorEnabled) Pawdo3DScene.interior,
      },
    );
  }

  final bool masterEnabled;
  final bool androidRuntime;
  final Set<Pawdo3DScene> enabledScenes;

  bool canLaunch(Pawdo3DScene scene) {
    return masterEnabled && androidRuntime && enabledScenes.contains(scene);
  }
}
