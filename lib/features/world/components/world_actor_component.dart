import 'package:flame/components.dart';

enum ActorState {
  idle,
  walking,
  sitting,
  sleeping,
  waving,
}

class WorldActorComponent extends SpriteComponent {
  Vector2 targetPosition;
  double speed;
  ActorState state = ActorState.idle;

  WorldActorComponent({
    required Sprite sprite,
    required Vector2 startPosition,
    required Vector2 size,
    Anchor anchor = Anchor.center,
    this.speed = 120,
  })  : targetPosition = startPosition.clone(),
        super(
          sprite: sprite,
          position: startPosition,
          size: size,
          anchor: anchor,
        );

  void moveTo(Vector2 target) {
    targetPosition = target.clone();
    state = ActorState.walking;
  }

  void idle() {
    state = ActorState.idle;
  }

  void sit() {
    state = ActorState.sitting;
  }

  void sleep() {
    state = ActorState.sleeping;
  }

  void wave() {
    state = ActorState.waving;
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
        state = ActorState.idle;
      } else {
        position += movement;
      }
    } else {
      if (state == ActorState.walking) {
        state = ActorState.idle;
      }
    }

    // Profundidad 2.5D: abajo = delante
    priority = position.y.toInt();
  }
}