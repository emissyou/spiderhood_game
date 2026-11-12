import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';

/// Projectile shot from MinionWithGun's rifle.
/// Uses the 'shoot effeck' asset as the bullet and emerges right from the gun barrel.
class GunBullet extends PositionComponent with CollisionCallbacks {
  final double direction; // +1.0 for right, -1.0 for left
  final double speed;
  final double maxDistance;
  final Vector2? targetPosition;
  late final Vector2 _velocityUnit;
  double _distanceTraveled = 0.0;

  Sprite? _bulletSprite;
  bool _hasHit = false;

  static final Paint _fallbackCorePaint = Paint()
    ..color = const Color(0xFFFFF07C)
    ..style = PaintingStyle.fill;
  static final Paint _fallbackGlowPaint = Paint()
    ..color = const Color(0xFFFF5722)
    ..style = PaintingStyle.fill;

  GunBullet({
    required Vector2 position,
    this.direction = -1.0,
    this.targetPosition,
    this.speed = 460.0,
    this.maxDistance = 2600.0,
  }) : super(
          position: position,
          size: Vector2(44, 12),
          anchor: Anchor.center,
        ) {
    if (targetPosition != null) {
      final diff = targetPosition! - position;
      _velocityUnit = diff.length > 0 ? diff.normalized() : Vector2(direction, 0.0);
    } else {
      _velocityUnit = Vector2(direction, 0.0);
    }

    if (_velocityUnit.x < 0) {
      angle = math.atan2(_velocityUnit.y, _velocityUnit.x) - math.pi;
    } else {
      angle = math.atan2(_velocityUnit.y, _velocityUnit.x);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    try {
      // Sub-rect cropping the actual beam/muzzle-flash from 552x356 canvas
      _bulletSprite = await Sprite.load(
        'enemies/minion_wgun/shoot effeck/1.png',
        srcPosition: Vector2(230, 135),
        srcSize: Vector2(256, 38),
      );
    } catch (_) {
      try {
        _bulletSprite = await Sprite.load('enemies/minion_wgun/shoot effeck/1.png');
      } catch (_) {
        _bulletSprite = null;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_hasHit) return;

    final moveDist = speed * dt;
    position += _velocityUnit * moveDist;
    _distanceTraveled += moveDist;

    // Check hit against player
    if (parent != null) {
      final bulletRect = toRect().inflate(4.0);
      final player = parent!.children.whereType<Spidey>().firstOrNull;
      if (player != null && !player.isDefeated && bulletRect.overlaps(player.toRect())) {
        _impactPlayer(player);
        return;
      }
    }

    if (_distanceTraveled >= maxDistance || position.x < -100 || position.x > 2500) {
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
    }
  }

  void _impactPlayer(Spidey player) {
    if (_hasHit) return;
    _hasHit = true;
    player.takeDamage(10); // Deals 1 heart damage
    Future.microtask(() {
      if (isMounted) removeFromParent();
    });
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (_hasHit) return;
    if (other is Spidey && !other.isDefeated) {
      _impactPlayer(other);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    if (direction < 0) {
      canvas.scale(-1.0, 1.0);
      canvas.translate(-size.x, 0.0);
    }

    if (_bulletSprite != null) {
      _bulletSprite!.render(canvas, size: size);
    } else {
      // High-visibility pixel laser fallback
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(3),
      );
      canvas.drawRRect(glowRect, _fallbackGlowPaint);

      final coreRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 2, math.max(4.0, size.x - 8), size.y - 4),
        const Radius.circular(2),
      );
      canvas.drawRRect(coreRect, _fallbackCorePaint);
    }
    canvas.restore();
  }
}
