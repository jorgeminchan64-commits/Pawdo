import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'depth_priority.dart';

/// A lightweight, deterministic finishing pass shared by the garden and room.
/// It adds the soft light, edge depth and tiny ambient motes that make the
/// pre-rendered art feel like one coherent 2.5D scene.
class SceneAtmosphereComponent extends PositionComponent {
  SceneAtmosphereComponent({required Vector2 sceneSize, required this.isIndoor})
    : _sceneRect = Rect.fromLTWH(0, 0, sceneSize.x, sceneSize.y),
      super(
        position: Vector2.zero(),
        size: sceneSize,
        anchor: Anchor.topLeft,
        priority: sceneDepthPriority(
          layer: SceneDepthLayer.overlay,
          baselineY: 0,
          tieBreaker: 999,
        ),
      ) {
    _warmLightPaint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x20FFF1C8), Color(0x00FFF8EF), Color(0x0AE7B6D5)],
      stops: [0, .48, 1],
    ).createShader(_sceneRect);
    _vignettePaint.shader = const RadialGradient(
      center: Alignment(0, -.05),
      radius: .88,
      colors: [Color(0x00000000), Color(0x00000000), Color(0x143B233E)],
      stops: [0, .72, 1],
    ).createShader(_sceneRect);
  }

  final bool isIndoor;
  final Rect _sceneRect;
  final Paint _warmLightPaint = Paint();
  final Paint _vignettePaint = Paint();
  double _elapsed = 0;

  static const _motes = <({double x, double y, double phase, double radius})>[
    (x: .10, y: .24, phase: .2, radius: 2.2),
    (x: .17, y: .58, phase: 1.1, radius: 1.6),
    (x: .25, y: .39, phase: 2.4, radius: 1.9),
    (x: .34, y: .70, phase: 3.2, radius: 2.3),
    (x: .43, y: .28, phase: 4.6, radius: 1.5),
    (x: .52, y: .60, phase: 5.1, radius: 1.8),
    (x: .61, y: .34, phase: 2.8, radius: 2.1),
    (x: .69, y: .73, phase: 1.8, radius: 1.6),
    (x: .77, y: .48, phase: 3.9, radius: 2.4),
    (x: .86, y: .25, phase: 5.8, radius: 1.7),
    (x: .91, y: .64, phase: .8, radius: 1.9),
  ];

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_sceneRect, _warmLightPaint);
    _renderMotes(canvas);
    canvas.drawRect(_sceneRect, _vignettePaint);
  }

  void _renderMotes(Canvas canvas) {
    final color = isIndoor ? const Color(0x66FFF4D1) : const Color(0x70FFF0F5);
    for (final mote in _motes) {
      final driftX = math.sin(_elapsed * .35 + mote.phase) * 8;
      final driftY = math.cos(_elapsed * .28 + mote.phase) * 5;
      final pulse = .72 + math.sin(_elapsed * .7 + mote.phase) * .20;
      canvas.drawCircle(
        Offset(size.x * mote.x + driftX, size.y * mote.y + driftY),
        mote.radius * (isIndoor ? .72 : 1),
        Paint()..color = color.withValues(alpha: color.a * pulse),
      );
    }
  }
}
