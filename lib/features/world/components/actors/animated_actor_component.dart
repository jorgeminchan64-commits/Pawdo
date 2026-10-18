import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../characters/models/character_appearance.dart';
import '../../models/actor_facing_policy.dart';
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

class ActorAppearanceLayers {
  const ActorAppearanceLayers({
    required this.appearance,
    required this.hairMask,
    required this.skinMask,
    required this.outfitMask,
    required this.shoesMask,
  });

  final CharacterAppearance appearance;
  final ui.Image hairMask;
  final ui.Image skinMask;
  final ui.Image outfitMask;
  final ui.Image shoesMask;
}

class AnimatedActorComponent
    extends SpriteAnimationGroupComponent<ActorAnimationState> {
  AnimatedActorComponent({
    required ui.Image spriteSheet,
    required Vector2 startPosition,
    required Vector2 size,
    required ActorSpriteLayout spriteLayout,
    this.appearanceLayers,
    Anchor anchor = Anchor.bottomCenter,
    this.speed = 120,
    this.depthTieBreaker = 0,
  }) : targetPosition = startPosition.clone(),
       renderBounds = size.clone(),
       super(
         position: startPosition,
         size: size,
         anchor: anchor,
         priority: sceneDepthPriority(
           layer: SceneDepthLayer.entity,
           baselineY: startPosition.y,
           tieBreaker: depthTieBreaker,
         ),
         current: ActorAnimationState.idle,
         animations: _buildAnimations(
           spriteSheet: spriteSheet,
           layout: spriteLayout,
         ),
       );

  Vector2 targetPosition;
  final Vector2 renderBounds;
  final int depthTieBreaker;
  final ActorAppearanceLayers? appearanceLayers;
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
  void render(Canvas canvas) {
    _renderGroundingShadow(canvas);
    final layers = appearanceLayers;
    super.render(canvas);

    final source = animationTicker?.getSprite();
    if (layers == null || source == null) return;

    _renderTintLayer(
      canvas,
      layers.skinMask,
      source,
      _skinColor(layers.appearance.skinTone),
    );
    _renderTintLayer(
      canvas,
      layers.hairMask,
      source,
      _hairColor(layers.appearance.hairColor),
    );
    _renderTintLayer(
      canvas,
      layers.outfitMask,
      source,
      _outfitColor(layers.appearance.outfitColor),
    );
    _renderTintLayer(
      canvas,
      layers.shoesMask,
      source,
      _shoeColor(layers.appearance.shoes),
    );
    _renderHairStyleAccents(canvas, layers.appearance);
    _renderOutfitStyleAccents(canvas, layers.appearance);
    _renderAccessory(canvas, layers.appearance);
    _renderExpressionAccent(canvas, layers.appearance);
  }

  void _renderGroundingShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x * .56,
        height: math.max(5, size.y * .035),
      ),
      Paint()
        ..color = const Color(0x382E2430)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _renderTintLayer(
    Canvas canvas,
    ui.Image mask,
    Sprite source,
    Color color,
  ) {
    Sprite(
      mask,
      srcPosition: source.srcPosition,
      srcSize: source.srcSize,
    ).render(
      canvas,
      size: size,
      overridePaint: Paint()
        ..colorFilter = ColorFilter.mode(color, BlendMode.modulate),
    );
  }

  void _renderAccessory(Canvas canvas, CharacterAppearance appearance) {
    if (current == ActorAnimationState.walkUp ||
        current == ActorAnimationState.walkSide ||
        current == ActorAnimationState.sleep) {
      return;
    }

    final center = Offset(_detailCenterX(appearance), size.y * .24);
    final scale = math.min(size.x, size.y) / 150;
    switch (appearance.accessory) {
      case CharacterAccessory.none:
        return;
      case CharacterAccessory.glasses:
        final stroke = Paint()
          ..color = const Color(0xFF4B394D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.1 * scale;
        canvas.drawCircle(center.translate(-7 * scale, 0), 5 * scale, stroke);
        canvas.drawCircle(center.translate(7 * scale, 0), 5 * scale, stroke);
        canvas.drawLine(
          center.translate(-2 * scale, 0),
          center.translate(2 * scale, 0),
          stroke,
        );
      case CharacterAccessory.heartPin:
        canvas.drawCircle(
          Offset(size.x * .64, size.y * .43),
          5.2 * scale,
          Paint()..color = const Color(0xFFE75A8C),
        );
      case CharacterAccessory.headband:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(_detailCenterX(appearance), size.y * .185),
            width: 28 * scale,
            height: 15 * scale,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFE75A8C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * scale
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  bool get _showsFrontDetails =>
      current != ActorAnimationState.walkUp &&
      current != ActorAnimationState.walkSide &&
      current != ActorAnimationState.sleep;

  void _renderHairStyleAccents(Canvas canvas, CharacterAppearance appearance) {
    if (!_showsFrontDetails ||
        appearance.hairStyle == CharacterHairStyle.short) {
      return;
    }
    final color = _hairColor(appearance.hairColor);
    final scale = math.min(size.x, size.y) / 150;
    final centerX = _detailCenterX(appearance);
    final highlight = Color.lerp(color, Colors.white, .28)!;
    final paint = Paint()
      ..color = highlight.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * scale
      ..strokeCap = StrokeCap.round;
    if (appearance.hairStyle == CharacterHairStyle.long) {
      final crown = Path()
        ..moveTo(centerX - size.x * .09, size.y * .18)
        ..quadraticBezierTo(
          centerX,
          size.y * .135,
          centerX + size.x * .09,
          size.y * .18,
        );
      final strand = Path()
        ..moveTo(centerX - size.x * .12, size.y * .20)
        ..quadraticBezierTo(
          centerX - size.x * .15,
          size.y * .24,
          centerX - size.x * .11,
          size.y * .275,
        );
      canvas.drawPath(crown, paint);
      canvas.drawPath(strand, paint);
      return;
    }
    final radius = math.max(2.3, 3.4 * scale);
    for (final point in <Offset>[
      Offset(centerX - size.x * .09, size.y * .16),
      Offset(centerX, size.y * .145),
      Offset(centerX + size.x * .09, size.y * .16),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: point, radius: radius),
        math.pi * .1,
        math.pi * 1.55,
        false,
        paint,
      );
    }
  }

  void _renderOutfitStyleAccents(
    Canvas canvas,
    CharacterAppearance appearance,
  ) {
    if (!_showsFrontDetails) return;
    final scale = math.min(size.x, size.y) / 150;
    final centerX = _detailCenterX(appearance);
    switch (appearance.outfitStyle) {
      case CharacterOutfitStyle.casual:
        return;
      case CharacterOutfitStyle.cozy:
        final scarf = Paint()
          ..color = const Color(0xFFF0B8CA)
          ..strokeWidth = 3.4 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(centerX, size.y * .39),
              width: size.x * .18,
              height: 4.5 * scale,
            ),
            Radius.circular(3 * scale),
          ),
          scarf,
        );
        canvas.drawLine(
          Offset(centerX + size.x * .055, size.y * .40),
          Offset(centerX + size.x * .075, size.y * .455),
          scarf,
        );
      case CharacterOutfitStyle.elegant:
        final accent = Paint()
          ..color = const Color(0xFFF7EDF5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(centerX - size.x * .06, size.y * .37),
          Offset(centerX, size.y * .43),
          accent,
        );
        canvas.drawLine(
          Offset(centerX + size.x * .06, size.y * .37),
          Offset(centerX, size.y * .43),
          accent,
        );
        canvas.drawLine(
          Offset(centerX - size.x * .11, size.y * .54),
          Offset(centerX + size.x * .11, size.y * .54),
          accent,
        );
    }
  }

  double _detailCenterX(CharacterAppearance appearance) {
    return size.x *
        (appearance.baseStyle == CharacterBaseStyle.classicBoy ? .59 : .5);
  }

  void _renderExpressionAccent(Canvas canvas, CharacterAppearance appearance) {
    if (!_showsFrontDetails ||
        appearance.expression != CharacterExpression.excited) {
      return;
    }
    final scale = math.min(size.x, size.y) / 150;
    final sparkle = Paint()
      ..color = const Color(0xFFFFC84A).withValues(alpha: .92)
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.x * .75, size.y * .18);
    canvas.drawLine(
      center.translate(-5 * scale, 0),
      center.translate(5 * scale, 0),
      sparkle,
    );
    canvas.drawLine(
      center.translate(0, -5 * scale),
      center.translate(0, 5 * scale),
      sparkle,
    );
    canvas.drawCircle(
      Offset(size.x * .36, size.y * .27),
      2.2 * scale,
      Paint()..color = const Color(0x66EF7FA4),
    );
    canvas.drawCircle(
      Offset(size.x * .64, size.y * .27),
      2.2 * scale,
      Paint()..color = const Color(0x66EF7FA4),
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
        scale.x = ActorFacingPolicy.horizontalScaleX(direction.x);
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

Color _skinColor(CharacterSkinTone value) => switch (value) {
  CharacterSkinTone.light => const Color(0xFFFFDCC7),
  CharacterSkinTone.warm => const Color(0xFFE2A27A),
  CharacterSkinTone.deep => const Color(0xFF986047),
};

Color _hairColor(CharacterHairColor value) => switch (value) {
  CharacterHairColor.brown => const Color(0xFF76503D),
  CharacterHairColor.black => const Color(0xFF29252D),
  CharacterHairColor.blonde => const Color(0xFFE1BC68),
  CharacterHairColor.copper => const Color(0xFFB96846),
};

Color _outfitColor(CharacterOutfitColor value) => switch (value) {
  CharacterOutfitColor.rose => const Color(0xFFE76998),
  CharacterOutfitColor.plum => const Color(0xFF754186),
  CharacterOutfitColor.blue => const Color(0xFF557FC0),
  CharacterOutfitColor.green => const Color(0xFF579276),
};

Color _shoeColor(CharacterShoes value) => switch (value) {
  CharacterShoes.sneakers => const Color(0xFFEFEAF2),
  CharacterShoes.boots => const Color(0xFF68483C),
};
