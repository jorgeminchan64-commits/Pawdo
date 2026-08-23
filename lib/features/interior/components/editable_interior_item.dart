import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../world/components/depth_priority.dart';

class EditableInteriorItem extends SpriteComponent {
  final String itemId;
  final String itemType;
  final String label;
  final String assetPath;
  final String? catalogItemId;
  final bool isSystemItem;
  final bool deletable;

  bool isSelected = false;
  double _lifeTime = 0;

  EditableInteriorItem({
    required this.itemId,
    required this.itemType,
    required this.label,
    required this.assetPath,
    this.catalogItemId,
    this.isSystemItem = false,
    bool? deletable,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required int priority,
  }) : deletable = deletable ?? !isSystemItem,
       super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: sceneDepthPriority(
           layer: itemType == 'rug'
               ? SceneDepthLayer.floor
               : SceneDepthLayer.entity,
           baselineY: position.y + size.y / 2,
           tieBreaker: stableDepthTieBreaker(itemId),
         ),
       );

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTime += dt;
    if (itemType == 'plant') {
      scale.x = 1 + math.sin(_lifeTime * .72 + _motionSeed) * .0035;
      scale.y = 1 + math.sin(_lifeTime * .64 + _motionSeed) * .002;
    }
    priority = sceneDepthPriority(
      layer: itemType == 'rug' ? SceneDepthLayer.floor : SceneDepthLayer.entity,
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
      'type': itemType,
      'label': label,
      'assetPath': assetPath,
      if (catalogItemId != null) 'catalogItemId': catalogItemId,
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

    final selectedPaint = Paint()
      ..color = const Color(0xFF8B3D96).withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      selectedPaint,
    );

    final dotPaint = Paint()..color = const Color(0xFFFDF8FC);
    final dotStroke = Paint()
      ..color = const Color(0xFF8B3D96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in <Offset>[
      const Offset(8, 3),
      Offset(size.x - 8, 3),
      Offset(8, size.y - 9),
      Offset(size.x - 8, size.y - 9),
    ]) {
      canvas.drawCircle(point, 5, dotPaint);
      canvas.drawCircle(point, 5, dotStroke);
    }
  }

  double get _motionSeed => (stableDepthTieBreaker(itemId) % 19) * .27;

  void _renderContactShadow(Canvas canvas) {
    if (itemType == 'rug') return;
    final profile = switch (itemType) {
      'bed' || 'sofa' => (width: .79, height: .12, alpha: .18),
      'table' || 'tv' => (width: .70, height: .12, alpha: .17),
      'plant' || 'lamp' => (width: .48, height: .10, alpha: .16),
      'pet_bed' => (width: .68, height: .14, alpha: .15),
      _ => (width: .62, height: .11, alpha: .14),
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
