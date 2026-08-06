import 'package:flame/components.dart';

class MovingSpriteComponent extends SpriteComponent {
  Vector2 targetPosition;
  double speed;

  MovingSpriteComponent({
    required Sprite sprite,
    required Vector2 startPosition,
    required Vector2 size,
    Anchor anchor = Anchor.center,
    this.speed = 70,
  })  : targetPosition = startPosition.clone(),
        super(
          sprite: sprite,
          position: startPosition,
          size: size,
          anchor: anchor,
        );

  void moveTo(Vector2 target) {
    targetPosition = target.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);

    final direction = targetPosition - position;
    final distance = direction.length;

    if (distance > 2) {
      if (direction.x.abs() > 1) {
        scale.x = direction.x < 0 ? -1 : 1;
      }

      final movement = direction.normalized() * speed * dt;

      if (movement.length >= distance) {
        position = targetPosition.clone();
      } else {
        position += movement;
      }
    }

    // Profundidad 2.5D
    priority = position.y.toInt();
  }
}