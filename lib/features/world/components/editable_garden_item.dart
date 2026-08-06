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
         priority: priority,
       );

  @override
  void update(double dt) {
    super.update(dt);
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
    super.render(canvas);

    if (!isSelected) return;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    final paint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
  }
}
