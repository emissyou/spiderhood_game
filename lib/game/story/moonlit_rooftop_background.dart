import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders the wide Moonlit Rooftop Cityscape environment (2172 x 724).
class MoonlitRooftopBackground extends PositionComponent {
  static const double mapWidth = 2172.0;
  static const double mapHeight = 724.0;

  Sprite? _bgSprite;
  late final Paint _ambientVignette;
  static const Rect _boundsRect = Rect.fromLTWH(0, 0, mapWidth, mapHeight);

  MoonlitRooftopBackground()
      : super(
          position: Vector2.zero(),
          size: Vector2(mapWidth, mapHeight),
        ) {
    _ambientVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.25),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.40),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(_boundsRect);
  }

  static final Paint _fallbackNightPaint = Paint()..color = const Color(0xFF0B1229);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _bgSprite = await Sprite.load('environment/Moonlit Rooftop Cityscape.png');
    } catch (_) {
      try {
        _bgSprite = await Sprite.load('environment/Moonlit Rooftop Cityscape.jpg');
      } catch (_) {}
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_bgSprite != null) {
      _bgSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      // Atmosphere vignette
      canvas.drawRect(_boundsRect, _ambientVignette);
    } else {
      canvas.drawRect(_boundsRect, _fallbackNightPaint);
    }
  }
}
