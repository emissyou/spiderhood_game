import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Building web anchor point located on building ledges, roofs, and cornices.
class WebAnchorPoint extends PositionComponent with HasGameReference {
  WebAnchorPoint({required Vector2 position})
      : super(position: position, size: Vector2(16, 16), anchor: Anchor.center);

  double _pulse = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3.5;
  }

  static final Paint _glowPaint = Paint()
    ..color = const Color(0x5900B4D8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final Paint _innerPaint = Paint()
    ..color = const Color(0xFF00B4D8)
    ..style = PaintingStyle.fill;

  static final Paint _borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static const Offset _center = Offset(8.0, 8.0);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Viewport culling: only render anchors within the active camera view
    final visible = game.camera.visibleWorldRect;
    if (position.x < visible.left - 30 || position.x > visible.right + 30) {
      return;
    }

    final ringRadius = 5.0 + math.sin(_pulse) * 1.5;

    // Glowing building anchor target (Cached Paints & Offset)
    canvas.drawCircle(_center, ringRadius + 3, _glowPaint);
    canvas.drawCircle(_center, 3.5, _innerPaint);
    canvas.drawCircle(_center, 3.5, _borderPaint);
  }
}
