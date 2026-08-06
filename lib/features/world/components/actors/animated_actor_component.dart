import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../depth_priority.dart';

enum ActorAnimationState {
  idle,
  walkDown,
  walkUp,
  walkSide,
  sit,
  water,
  wave,
  hug,
  sleep,
}

class ActorSpriteLayout {
  const ActorSpriteLayout({
    required this.xEdges,
    required this.yEdges,
    this.isPet = false,
  });

  final List<double> xEdges;
  final List<double> yEdges;
  final bool isPet;

  static const boy = ActorSpriteLayout(
    xEdges: [0, 211, 412, 606, 836],
    yEdges: [0, 235, 455, 674, 875, 1079, 1287, 1507, 1710, 1881],
  );
  static const girl = ActorSpriteLayout(
    xEdges: [0, 235, 432, 628, 836],
    yEdges: [0, 233, 450, 668, 888, 1095, 1304, 1530, 1709, 1881],
  );
  static const dog = ActorSpriteLayout(
    xEdges: [0, 223, 416, 613, 836],
    yEdges: [0, 245, 449, 657, 851, 1067, 1283, 1475, 1678, 1881],
    isPet: true,
  );

  int rowFor(ActorAnimationState state) {
    if (!isPet) return state.index;
    return switch (state) {
      ActorAnimationState.idle => 0,
      ActorAnimationState.walkDown => 1,
      ActorAnimationState.walkUp => 2,
      ActorAnimationState.walkSide => 3,
      ActorAnimationState.sit || ActorAnimationState.water => 4,
      ActorAnimationState.wave || ActorAnimationState.hug => 5,
      ActorAnimationState.sleep => 8,
    };
  }
}

class AnimatedActorComponent
    extends SpriteAnimationGroupComponent<ActorAnimationState> {
  AnimatedActorComponent({
    required ui.Image spriteSheet,
    required Vector2 startPosition,
    required Vector2 size,
    required ActorSpriteLayout spriteLayout,
    Anchor anchor = Anchor.bottomCenter,
    this.speed = 120,
    this.depthTieBreaker = 0,
  }) : targetPosition = startPosition.clone(),
       renderBounds = size.clone(),
       super(
         position: startPosition,
         size: size,
         anchor: anchor,
         current: ActorAnimationState.idle,
         animations: _buildAnimations(
           spriteSheet: spriteSheet,
           layout: spriteLayout,
         ),
       );

  Vector2 targetPosition;
  final Vector2 renderBounds;
  final int depthTieBreaker;
  double speed;

  final List<Vector2> _path = [];
  double _actionTimer = 0;

  bool get isMoving =>
      _path.isNotEmpty || (targetPosition - position).length > 4;

  static Map<ActorAnimationState, SpriteAnimation> _buildAnimations({
    required ui.Image spriteSheet,
    required ActorSpriteLayout layout,
  }) {
    SpriteAnimation makeAnimation(
      ActorAnimationState state, {
      double stepTime = 0.16,
    }) {
      final row = layout.rowFor(state);
      final sprites = List<Sprite>.generate(4, (column) {
        final left = layout.xEdges[column];
        final top = layout.yEdges[row];
        return Sprite(
          spriteSheet,
          srcPosition: Vector2(left, top),
          srcSize: Vector2(
            layout.xEdges[column + 1] - left,
            layout.yEdges[row + 1] - top,
          ),
        );
      });
      return SpriteAnimation.spriteList(
        sprites,
        stepTime: stepTime,
        loop: true,
      );
    }

    return {
      ActorAnimationState.idle: makeAnimation(
        ActorAnimationState.idle,
        stepTime: .35,
      ),
      ActorAnimationState.walkDown: makeAnimation(
        ActorAnimationState.walkDown,
        stepTime: .14,
      ),
      ActorAnimationState.walkUp: makeAnimation(
        ActorAnimationState.walkUp,
        stepTime: .14,
      ),
      ActorAnimationState.walkSide: makeAnimation(
        ActorAnimationState.walkSide,
        stepTime: .14,
      ),
      ActorAnimationState.sit: makeAnimation(
        ActorAnimationState.sit,
        stepTime: .22,
      ),
      ActorAnimationState.water: makeAnimation(
        ActorAnimationState.water,
        stepTime: .18,
      ),
      ActorAnimationState.wave: makeAnimation(
        ActorAnimationState.wave,
        stepTime: .18,
      ),
      ActorAnimationState.hug: makeAnimation(
        ActorAnimationState.hug,
        stepTime: .22,
      ),
      ActorAnimationState.sleep: makeAnimation(
        ActorAnimationState.sleep,
        stepTime: .35,
      ),
    };
  }

  void moveTo(Vector2 target) {
    _path.clear();
    targetPosition = target.clone();
    _actionTimer = 0;
  }

  void movePath(List<Vector2> points) {
    _path.clear();
    if (points.isEmpty) return;
    _path.addAll(points.map((point) => point.clone()));
    targetPosition = _path.removeAt(0);
    _actionTimer = 0;
  }

  void sit() => _playAction(ActorAnimationState.sit, 3);
  void water() => _playAction(ActorAnimationState.water, 2.5);
  void wave() => _playAction(ActorAnimationState.wave, 1.8);
  void hug() => _playAction(ActorAnimationState.hug, 2.5);
  void sleep() => _playAction(ActorAnimationState.sleep, 3);

  void _playAction(ActorAnimationState action, double seconds) {
    _path.clear();
    targetPosition = position.clone();
    current = action;
    _actionTimer = seconds;
  }

  void _fitCurrentFrame() {
    final sprite = animationTicker?.getSprite();
    if (sprite == null || sprite.srcSize.x <= 0 || sprite.srcSize.y <= 0) {
      return;
    }
    final factor = math.min(
      renderBounds.x / sprite.srcSize.x,
      renderBounds.y / sprite.srcSize.y,
    );
    size.setValues(sprite.srcSize.x * factor, sprite.srcSize.y * factor);
  }

  void _updateDepth() {
    priority = sceneDepthPriority(
      layer: SceneDepthLayer.entity,
      baselineY: position.y,
      tieBreaker: depthTieBreaker,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fitCurrentFrame();

    if (_actionTimer > 0) {
      _actionTimer -= dt;
      if (_actionTimer <= 0) current = ActorAnimationState.idle;
      _updateDepth();
      return;
    }

    final direction = targetPosition - position;
    final distance = direction.length;
    if (distance > 4) {
      if (direction.x.abs() > direction.y.abs()) {
        current = ActorAnimationState.walkSide;
        scale.x = direction.x < 0 ? -1 : 1;
      } else {
        scale.x = 1;
        current = direction.y < 0
            ? ActorAnimationState.walkUp
            : ActorAnimationState.walkDown;
      }
      final movement = direction.normalized() * speed * dt;
      if (movement.length >= distance) {
        position = targetPosition.clone();
        if (_path.isNotEmpty) {
          targetPosition = _path.removeAt(0);
        } else {
          current = ActorAnimationState.idle;
        }
      } else {
        position += movement;
      }
    } else {
      position = targetPosition.clone();
      if (_path.isNotEmpty) {
        targetPosition = _path.removeAt(0);
      } else {
        current = ActorAnimationState.idle;
      }
    }
    _updateDepth();
  }
}
