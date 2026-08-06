import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/world/components/actors/animated_actor_component.dart';
import 'package:pawdo/features/world/components/depth_priority.dart';

void main() {
  test('depth layers keep floor, entities and overlays ordered', () {
    final background = sceneDepthPriority(
      layer: SceneDepthLayer.background,
      baselineY: 900,
    );
    final floor = sceneDepthPriority(
      layer: SceneDepthLayer.floor,
      baselineY: 900,
    );
    final entityBack = sceneDepthPriority(
      layer: SceneDepthLayer.entity,
      baselineY: 400,
    );
    final entityFront = sceneDepthPriority(
      layer: SceneDepthLayer.entity,
      baselineY: 700,
    );
    final overlay = sceneDepthPriority(
      layer: SceneDepthLayer.overlay,
      baselineY: 0,
    );

    expect(background, lessThan(floor));
    expect(floor, lessThan(entityBack));
    expect(entityBack, lessThan(entityFront));
    expect(entityFront, lessThan(overlay));
  });

  test('sprite layouts match the real atlas edges', () {
    for (final layout in [
      ActorSpriteLayout.boy,
      ActorSpriteLayout.girl,
      ActorSpriteLayout.dog,
    ]) {
      expect(layout.xEdges.length, 5);
      expect(layout.yEdges.length, 10);
      expect(layout.xEdges.first, 0);
      expect(layout.xEdges.last, 836);
      expect(layout.yEdges.first, 0);
      expect(layout.yEdges.last, 1881);
      for (var index = 1; index < layout.xEdges.length; index++) {
        expect(layout.xEdges[index], greaterThan(layout.xEdges[index - 1]));
      }
      for (var index = 1; index < layout.yEdges.length; index++) {
        expect(layout.yEdges[index], greaterThan(layout.yEdges[index - 1]));
      }
    }
  });

  test('dog actions never reuse incompatible human-only rows', () {
    expect(
      ActorSpriteLayout.dog.rowFor(ActorAnimationState.water),
      ActorSpriteLayout.dog.rowFor(ActorAnimationState.sit),
    );
    expect(
      ActorSpriteLayout.dog.rowFor(ActorAnimationState.hug),
      ActorSpriteLayout.dog.rowFor(ActorAnimationState.wave),
    );
    expect(ActorSpriteLayout.dog.rowFor(ActorAnimationState.sleep), 8);
  });
}
