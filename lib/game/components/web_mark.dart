import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Web mark / splat left at the anchor tip after each swing.
/// Dissolves smoothly over 7 seconds.
class WebMark extends PositionComponent with HasGameReference {
  static const double duration = 7.0;
  double _remaining = duration;
  Sprite? _markSprite;
  final Paint _paint = Paint();

  WebMark({required Vector2 position})
      : super(
          position: position,
          size: Vector2(22, 17),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _markSprite = await Sprite.load('player/web_swing/4.png');
    } catch (_) {
      _markSprite = null;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    if (_remaining <= 0) {
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Progress from 1.0 down to 0.0 over 7 seconds
    final progress = (_remaining / duration).clamp(0.0, 1.0);
    // Smooth dissolve curve: stay visible and dissolve away across the 7 seconds
    final alpha = (progress / 0.75).clamp(0.0, 1.0);

    _paint.color = Colors.white.withValues(alpha: alpha);
    if (_markSprite != null) {
      _markSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
        overridePaint: _paint,
      );
    } else {
      // Fallback web splat
      _paint.color = Colors.white.withValues(alpha: alpha * 0.8);
      _paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), 6, _paint);
    }
  }
}
