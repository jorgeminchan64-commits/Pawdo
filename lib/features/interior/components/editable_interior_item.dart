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
         priority: priority,
       );

  @override
  void update(double dt) {
    super.update(dt);
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
    super.render(canvas);

    if (!isSelected) return;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    final selectedPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      selectedPaint,
    );

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(10, 10), 6, dotPaint);
    canvas.drawCircle(Offset(size.x - 10, 10), 6, dotPaint);
    canvas.drawCircle(Offset(10, size.y - 10), 6, dotPaint);
    canvas.drawCircle(Offset(size.x - 10, size.y - 10), 6, dotPaint);
  }
}
