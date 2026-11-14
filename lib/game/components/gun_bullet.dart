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
          size: Vector2(30, 8),
          anchor: Anchor.center,
        ) {
    if (targetPosition != null) {
      final diff = targetPosition! - position;
      _velocityUnit = diff.length > 0 ? diff.normalized() : Vector2(direction, 0.0);
    } else {
      _velocityUnit = Vector2(direction, 0.0);
    }

    // Bullet rotates accurately towards its travel vector
    angle = math.atan2(_velocityUnit.y, _velocityUnit.x);
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

    final prevPosition = position.clone();
    final moveDist = speed * dt;
    position += _velocityUnit * moveDist;
    _distanceTraveled += moveDist;

    // Check hit against player - swept segment ensures fast bullets never tunnel through player's body
    if (parent != null) {
      final player = parent!.children.whereType<Spidey>().firstOrNull;
      if (player != null && !player.isDefeated) {
        final playerBody = player.toRect();
        final sweptRect = Rect.fromPoints(
          Offset(
            math.min(prevPosition.x, position.x) - size.x * 0.5,
            math.min(prevPosition.y, position.y) - size.y * 0.5,
          ),
          Offset(
            math.max(prevPosition.x, position.x) + size.x * 0.5,
            math.max(prevPosition.y, position.y) + size.y * 0.5,
          ),
        );
        if (sweptRect.overlaps(playerBody)) {
          _impactPlayer(player);
          return;
        }
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
    final knockbackDir = direction >= 0 ? 1.0 : -1.0;
    if (player.state == SpideyState.swinging) {
      player.releaseWeb();
    }
    player.takeDamage(10); // Deals 1 heart damage
    // Moderate, punchy stagger knockback that doesn't fling the player too far
    player.velocity.x = knockbackDir * 85.0;
    player.velocity.y = -50.0;
    player.isGrounded = false;
    player.currentPlatform = null;
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
        Rect.fromLTWH(2, 1, math.max(4.0, size.x - 4), size.y - 2),
        const Radius.circular(2),
      );
      canvas.drawRRect(coreRect, _fallbackCorePaint);
    }
  }
}
