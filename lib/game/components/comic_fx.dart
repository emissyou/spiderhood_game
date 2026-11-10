import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Comic book dynamic pop-up text ("POW!", "THWIP!", "BAM!", "WHAM!")
/// Renders a cartoon starburst badge with stylized comic typography.
class ComicFx extends PositionComponent {
  final String text;
  final Color badgeColor;
  final Color textColor;
  final double maxDuration;

  double _elapsed = 0.0;
  final double _initialAngle;

  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.0;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  ComicFx({
    required this.text,
    required Vector2 position,
    this.badgeColor = const Color(0xFFFFD500),
    this.textColor = const Color(0xFFD90429),
    this.maxDuration = 0.65,
  })  : _initialAngle = (math.Random().nextDouble() - 0.5) * 0.4,
        super(position: position, size: Vector2(130, 65), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= maxDuration) {
      removeFromParent();
      return;
    }

    final progress = _elapsed / maxDuration;
    final scaleFactor = progress < 0.2
        ? (progress / 0.2) * 1.25
        : (1.25 - (progress - 0.2) * 0.3);

    scale = Vector2.all(scaleFactor);
    angle = _initialAngle;
    position.y -= dt * 40.0; // slight upward float
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = _elapsed / maxDuration;
    final opacity = (1.0 - math.pow(progress, 3)).clamp(0.0, 1.0).toDouble();

    final center = (size / 2).toOffset();
    final radius = size.x * 0.45;

    // Draw cartoon jagged starburst
    final starburstPath = Path();
    const points = 12;
    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? radius : radius * 0.65;
      final a = (i * math.pi) / points;
      final x = center.dx + r * math.cos(a);
      final y = center.dy + r * math.sin(a);
      if (i == 0) {
        starburstPath.moveTo(x, y);
      } else {
        starburstPath.lineTo(x, y);
      }
    }
    starburstPath.close();

    // Black comic outline
    _strokePaint.color = Colors.black.withValues(alpha: opacity);
    canvas.drawPath(starburstPath, _strokePaint);

    // Starburst fill
    _fillPaint.color = badgeColor.withValues(alpha: opacity);
    canvas.drawPath(starburstPath, _fillPaint);

    // Stylized Comic Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor.withValues(alpha: opacity),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              offset: const Offset(2.0, 2.0),
              color: Colors.black.withValues(alpha: opacity),
              blurRadius: 0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }
}
