import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/config/game_config.dart';

/// Renders the custom New York Morning background image ONCE across the level.
/// The game boundaries follow the image exact dimensions: 2086 x 754 (no infinite loop).
class NyBackground extends PositionComponent with HasGameReference {
  Sprite? _bgSprite;
  bool _isLoaded = false;

  static const double bgWidth = GameConfig.bgWidth;   // 2086.0
  static const double bgHeight = GameConfig.bgHeight; // 754.0

  static const Rect _bgRect = Rect.fromLTWH(0, 0, bgWidth, bgHeight);
  static final Vector2 _renderPos = Vector2.zero();
  static final Vector2 _renderSize = Vector2(bgWidth, bgHeight);
  static final Paint _fallbackPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2B2D42),
        Color(0xFF8D99AE),
        Color(0xFFEDF2F4),
      ],
    ).createShader(_bgRect);

  NyBackground() : super(position: Vector2.zero(), size: Vector2(bgWidth, bgHeight));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _bgSprite = await Sprite.load('environment/new_york_morning.png');
      _isLoaded = true;
    } catch (_) {
      _isLoaded = false;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_isLoaded && _bgSprite != null) {
      _bgSprite!.render(
        canvas,
        position: _renderPos,
        size: _renderSize,
      );
    } else {
      // Fallback sky gradient if asset is still loading or in test harness
      canvas.drawRect(_bgRect, _fallbackPaint);
    }
  }
}
