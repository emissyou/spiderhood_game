import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/config/game_config.dart';

/// Neighborhood civilian walking along the sidewalk.
/// Supports both civilian_1 and civilian_2 variants with animated walking cycles.
class Civilian extends PositionComponent with HasGameReference {
  final int variant; // 1 for civilian_1 (4 frames), 2 for civilian_2 (6 frames)
  double direction; // 1.0 for right, -1.0 for left
  final double speed;
  final double minX;
  final double maxX;

  static final List<Sprite> _sharedVariant1 = [];
  static final List<Sprite> _sharedVariant2 = [];

  int _currentFrame = 0;
  double _animTimer = 0.0;
  static const double frameDuration = 0.16;

  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35);
  static final Paint _fallbackBodyPaint = Paint()
    ..color = const Color(0xFFFFB703);

  late final Rect _shadowRect;
  late final Rect _fallbackBodyRect;
  late final Vector2 _renderPos;

  Civilian({
    required Vector2 position,
    this.variant = 1,
    this.direction = 1.0,
    this.speed = 42.0,
    this.minX = 40.0,
    this.maxX = GameConfig.bgWidth - 40.0,
  }) : super(
          position: position,
          size: Vector2(21.0, 38.0),
          anchor: Anchor.bottomCenter,
        );

  List<Sprite> get _activeSprites => variant == 2 ? _sharedVariant2 : _sharedVariant1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _shadowRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x * 0.95,
      height: 4.0,
    );
    _fallbackBodyRect = Rect.fromLTWH(-size.x / 2, -size.y, size.x, size.y);
    _renderPos = Vector2(-size.x / 2, -size.y);

    if (variant == 2 && _sharedVariant2.isEmpty) {
      for (int i = 1; i <= 6; i++) {
        try {
          final sprite = await Sprite.load('civilian/civilian_2/walking/$i.png');
          _sharedVariant2.add(sprite);
        } catch (_) {}
      }
    } else if (variant == 1 && _sharedVariant1.isEmpty) {
      for (int i = 1; i <= 4; i++) {
        try {
          final sprite = await Sprite.load('civilian/civilian_1/walking/$i.png');
          _sharedVariant1.add(sprite);
        } catch (_) {}
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Keep firmly grounded on the sidewalk
    position.y = GameConfig.groundY;

    // Move horizontally
    position.x += direction * speed * dt;

    // Turn around at patrol / screen boundaries
    if (position.x <= minX) {
      position.x = minX;
      direction = 1.0;
    } else if (position.x >= maxX) {
      position.x = maxX;
      direction = -1.0;
    }

    // Advance walking animation
    final sprites = _activeSprites;
    if (sprites.isNotEmpty) {
      _animTimer += dt;
      if (_animTimer >= frameDuration) {
        _animTimer -= frameDuration;
        _currentFrame = (_currentFrame + 1) % sprites.length;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Viewport culling: only render civilians within the active camera view
    final visible = game.camera.visibleWorldRect;
    if (position.x < visible.left - 60 || position.x > visible.right + 60) {
      return;
    }

    // Ground contact shadow
    canvas.drawOval(_shadowRect, _shadowPaint);

    canvas.save();
    // Flip horizontally when walking left
    if (direction < 0) {
      canvas.scale(-1, 1);
    }

    final sprites = _activeSprites;
    if (sprites.isNotEmpty && _currentFrame < sprites.length) {
      final sprite = sprites[_currentFrame];
      sprite.render(
        canvas,
        position: _renderPos,
        size: size,
      );
    } else {
      // Fallback cartoon civilian
      canvas.drawRRect(
        RRect.fromRectAndRadius(_fallbackBodyRect, const Radius.circular(4)),
        _fallbackBodyPaint,
      );
    }

    canvas.restore();
  }
}
