import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/config/game_config.dart';

/// Yellow NYC Taxi driving on the road lane below the sidewalk level.
/// Spawns 4 vehicles looping with collision avoidance to prevent overlapping.
class Taxi extends PositionComponent with HasGameReference {
  final int taxiIndex; // 1 to 4
  final double direction; // 1.0 for moving right
  final double baseSpeed;

  static final List<Sprite> _sharedTaxiSprites = [];
  static final List<Taxi> _activeTaxis = [];

  int _currentFrame = 0;
  double _animTimer = 0.0;
  static const double frameDuration = 0.12;
  static const double buffer = 120.0;

  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.40);
  static final Paint _fallbackCabPaint = Paint()
    ..color = const Color(0xFFFFD166);

  late final Rect _shadowRect;
  late final Rect _fallbackBodyRect;
  late final Vector2 _renderPos;

  Taxi({
    required Vector2 position,
    this.taxiIndex = 1,
    this.direction = 1.0,
    this.baseSpeed = 160.0,
  }) : super(
          position: position,
          size: Vector2(88.0, 44.0),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (!_activeTaxis.contains(this)) {
      _activeTaxis.add(this);
    }

    _shadowRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x * 0.95,
      height: 5.0,
    );
    _fallbackBodyRect = Rect.fromLTWH(-size.x / 2, -size.y, size.x, size.y);
    _renderPos = Vector2(-size.x / 2, -size.y);

    if (_sharedTaxiSprites.isEmpty) {
      for (int i = 1; i <= 4; i++) {
        try {
          final sprite = await Sprite.load('car/taxi/$i.png');
          _sharedTaxiSprites.add(sprite);
        } catch (_) {}
      }
    }
    _currentFrame = (taxiIndex - 1) % (_sharedTaxiSprites.isNotEmpty ? _sharedTaxiSprites.length : 1);
  }

  @override
  void onRemove() {
    _activeTaxis.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Keep below Spidey's ground level on the street road lane
    position.y = 750.0;

    // Active speed with collision-avoidance following distance (direct list lookup)
    double currentSpeed = baseSpeed;
    final totalTrack = GameConfig.bgWidth + buffer * 2;
    for (final other in _activeTaxis) {
      if (identical(other, this)) continue;
      double distAhead = other.position.x - position.x;
      if (distAhead < 0) {
        distAhead += totalTrack;
      }
      // If getting within following distance (140px), match speed or gently brake
      if (distAhead > 0 && distAhead < 140.0) {
        final factor = (distAhead / 140.0).clamp(0.2, 1.0);
        currentSpeed = math.min(currentSpeed, baseSpeed * factor);
      }
    }

    // Cruise horizontally
    position.x += direction * currentSpeed * dt;

    // Loop endlessly across screen bounds
    if (direction > 0 && position.x > GameConfig.bgWidth + buffer) {
      position.x = -buffer;
    } else if (direction < 0 && position.x < -buffer) {
      position.x = GameConfig.bgWidth + buffer;
    }

    // Wheel rotation and engine vibration
    if (_sharedTaxiSprites.isNotEmpty) {
      _animTimer += dt;
      if (_animTimer >= frameDuration) {
        _animTimer -= frameDuration;
        _currentFrame = (_currentFrame + 1) % _sharedTaxiSprites.length;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Viewport culling: only render taxis within the active camera section
    final visible = game.camera.visibleWorldRect;
    if (position.x < visible.left - 100 || position.x > visible.right + 100) {
      return;
    }

    // Road shadow under tires
    canvas.drawOval(_shadowRect, _shadowPaint);

    canvas.save();
    if (direction < 0) {
      canvas.scale(-1, 1);
    }

    if (_sharedTaxiSprites.isNotEmpty) {
      final sprite = _sharedTaxiSprites[_currentFrame % _sharedTaxiSprites.length];
      sprite.render(
        canvas,
        position: _renderPos,
        size: size,
      );
    } else {
      // Fallback taxi yellow cab
      canvas.drawRRect(
        RRect.fromRectAndRadius(_fallbackBodyRect, const Radius.circular(5)),
        _fallbackCabPaint,
      );
    }

    canvas.restore();
  }
}
