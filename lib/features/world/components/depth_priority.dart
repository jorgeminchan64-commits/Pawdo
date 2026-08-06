enum SceneDepthLayer { background, floor, entity, overlay }

int sceneDepthPriority({
  required SceneDepthLayer layer,
  required double baselineY,
  int tieBreaker = 0,
}) {
  final layerOffset = switch (layer) {
    SceneDepthLayer.background => -1000000,
    SceneDepthLayer.floor => -500000,
    SceneDepthLayer.entity => 0,
    SceneDepthLayer.overlay => 1000000,
  };
  return layerOffset + (baselineY * 10).round() + tieBreaker.clamp(0, 9);
}

int stableDepthTieBreaker(String id) {
  return id.codeUnits.fold<int>(0, (sum, value) => sum + value) % 10;
}
