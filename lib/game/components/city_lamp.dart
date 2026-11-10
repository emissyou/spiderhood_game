import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Animated outdoor lantern light rendering a procedural golden starburst flare.
/// Features a brilliant white-gold core, cross-star spikes, radial corona glow,
/// and shimmering starlight embers matching the reference visual style.
class CityLamp extends PositionComponent with HasGameReference {
  final double phase;

  static final Path _starPath = Path()
    ..moveTo(-18, 0)
    ..lineTo(0, -1.8)
    ..lineTo(18, 0)
    ..lineTo(0, 1.8)
    ..close()
    ..moveTo(0, -18)
    ..lineTo(-1.8, 0)
    ..lineTo(0, 18)
    ..lineTo(1.8, 0)
    ..close()
    ..moveTo(-9, -9)
    ..lineTo(0, -1.0)
    ..lineTo(9, -9)
    ..lineTo(1.0, 0)
    ..lineTo(9, 9)
    ..lineTo(0, 1.0)
    ..lineTo(-9, 9)
    ..lineTo(-1.0, 0)
    ..close();

  static final Paint _coronaPaint = Paint()
    ..color = const Color(0x55FDE047)
    ..style = PaintingStyle.fill;

  static final Paint _starPaint = Paint()
    ..color = const Color(0xFFFFFBEB)
    ..style = PaintingStyle.fill;

  static final Paint _corePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  CityLamp({
    required Vector2 position,
    this.phase = 0.0,
  }) : super(
          position: position,
          size: Vector2(36, 36),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Soft radial corona glow (Cached)
    canvas.drawCircle(Offset.zero, 16.0, _coronaPaint);

    // 2. High-performance 8-point golden cross starburst flare (Precomputed)
    canvas.drawPath(_starPath, _starPaint);

    // 3. Intense brilliant white core
    canvas.drawCircle(Offset.zero, 3.2, _corePaint);
  }
}
