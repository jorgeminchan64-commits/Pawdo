import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'depth_priority.dart';

class EditableGardenItem extends SpriteComponent {
  final String itemId;
  final String catalogItemId;
  final String itemType;
  final String assetPath;
  final bool isSystemItem;
  final bool deletable;

  bool isSelected = false;
  double _lifeTime = 0;

  EditableGardenItem({
    required this.itemId,
    required this.catalogItemId,
    required this.itemType,
    required this.assetPath,
    this.isSystemItem = false,
    this.deletable = true,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required int priority,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: sceneDepthPriority(
           layer: SceneDepthLayer.entity,
           baselineY: position.y + size.y / 2,
           tieBreaker: stableDepthTieBreaker(itemId),
         ),
       );

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTime += dt;
    if (_hasLivingMotion) {
      scale.x = 1 + math.sin(_lifeTime * .85 + _motionSeed) * .004;
      scale.y = 1 + math.sin(_lifeTime * .72 + _motionSeed) * .002;
    }
    priority = sceneDepthPriority(
      layer: SceneDepthLayer.entity,
      baselineY: position.y + size.y / 2,
      tieBreaker: stableDepthTieBreaker(itemId),
    );
  }

  bool containsWorldPoint(Vector2 point) {
    final left = position.x - size.x / 2;
    final right = position.x + size.x / 2;
    final top = position.y - size.y / 2;
    final bottom = position.y + size.y / 2;

    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': itemId,
      'catalogItemId': catalogItemId,
      'type': itemType,
      'asset': assetPath,
      'isSystemItem': isSystemItem,
      'deletable': deletable,
      'x': position.x,
      'y': position.y,
      'width': size.x,
      'height': size.y,
      'priority': priority,
    };
  }

  @override
  void render(Canvas canvas) {
    _renderContactShadow(canvas);

    canvas.save();
    if (isSelected) canvas.translate(0, -5);
    super.render(canvas);
    canvas.restore();

    if (!isSelected) return;

    final rect = Rect.fromLTWH(2, -3, size.x - 4, size.y - 4);
    final paint = Paint()
      ..color = const Color(0xFF8B3D96).withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      paint,
    );

    final handlePaint = Paint()..color = const Color(0xFFFDF8FC);
    final handleStroke = Paint()
      ..color = const Color(0xFF8B3D96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in <Offset>[
      const Offset(8, 3),
      Offset(size.x - 8, 3),
      Offset(8, size.y - 9),
      Offset(size.x - 8, size.y - 9),
    ]) {
      canvas.drawCircle(point, 5, handlePaint);
      canvas.drawCircle(point, 5, handleStroke);
    }
  }

  bool get _hasLivingMotion =>
      itemType == 'plant' ||
      itemType == 'special_plant' ||
      itemType == 'pot' ||
      itemType == 'flowers' ||
      itemType == 'bush';

  double get _motionSeed => (stableDepthTieBreaker(itemId) % 17) * .31;

  void _renderContactShadow(Canvas canvas) {
    if (itemType == 'flowers') return;
    final profile = switch (itemType) {
      'tree' => (width: .58, height: .10, alpha: .19),
      'table' => (width: .70, height: .13, alpha: .18),
      'bush' => (width: .74, height: .16, alpha: .15),
      'plant' ||
      'special_plant' ||
      'pot' => (width: .55, height: .12, alpha: .17),
      _ => (width: .62, height: .11, alpha: .13),
    };
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .89),
        width: size.x * profile.width,
        height: math.max(5, size.y * profile.height),
      ),
      Paint()
        ..color = const Color(0xFF392A35).withValues(alpha: profile.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
