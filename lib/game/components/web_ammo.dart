import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/enemies/thug.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';

/// Web projectile shot during Spidey's Skill 1 attack.
/// Emerges right from Spidey's outstretched hand and travels rapidly horizontally.
class WebAmmo extends PositionComponent with CollisionCallbacks, HasGameReference {
  final double direction; // +1.0 for right, -1.0 for left
  final double speed;
  final double maxDistance;
  double _distanceTraveled = 0.0;

  Sprite? _ammoSprite;

  static final Paint _beamPaint = Paint()..color = Colors.white;
  static final Paint _trailPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.45)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  WebAmmo({
    required Vector2 position,
    required this.direction,
    this.speed = 780.0,
    this.maxDistance = 750.0,
  }) : super(
          position: position,
          size: Vector2(78, 22),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    // Load updated ammo sprite (web_shoot.png, 325x50)
    try {
      _ammoSprite = await Sprite.load('player/skill_1/web_shoot.png');
    } catch (_) {
      try {
        _ammoSprite = await Sprite.load('player/skill_1/4.png');
      } catch (_) {
        try {
          _ammoSprite = await Sprite.load('player/skill_1/weebshoot.png');
        } catch (_) {
          _ammoSprite = null;
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final moveDist = speed * dt;
    position.x += direction * moveDist;
    _distanceTraveled += moveDist;

    // Proactive overlap check so fast-moving projectile never tunnels or misses
    if (parent != null) {
      final ammoBox = toRect().inflate(8.0);
      for (final boss in parent!.children.whereType<ViperBoss>()) {
        if (boss.bossState != BossState.escaped && ammoBox.overlaps(boss.toRect())) {
          boss.hitByWeb(direction);
          removeFromParent();
          return;
        }
      }
      for (final guard in parent!.children.whereType<ViperGuard>()) {
        if (!guard.isDefeated && ammoBox.overlaps(guard.toRect())) {
          guard.hitByWeb(direction);
          removeFromParent();
          return;
        }
      }
      for (final thug in parent!.children.whereType<Thug>()) {
        if (!thug.isDefeated && ammoBox.overlaps(thug.toRect())) {
          thug.takeDamage(35, direction);
          removeFromParent();
          return;
        }
      }
    }

    // Despawn if out of range or off-screen
    if (_distanceTraveled >= maxDistance || position.x < -100) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Thug && !other.isDefeated) {
      other.takeDamage(35, direction);
      removeFromParent();
    } else if (other is ViperBoss && other.bossState != BossState.escaped) {
      other.hitByWeb(direction);
      removeFromParent();
    } else if (other is ViperGuard && !other.isDefeated) {
      other.hitByWeb(direction);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Orient towards movement direction
    if (direction < 0) {
      canvas.scale(-1, 1);
    }

    if (_ammoSprite != null) {
      _ammoSprite!.render(
        canvas,
        position: Vector2(-size.x / 2, -size.y / 2),
        size: size,
      );
    } else {
      // Fallback comic web blast graphic
      final beamRect = Rect.fromCenter(
        center: Offset.zero,
        width: size.x,
        height: size.y * 0.45,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(beamRect, const Radius.circular(3)),
        _beamPaint,
      );
    }

    // Subtle comic motion streaks behind the web shot
    canvas.drawLine(
      Offset(-size.x / 2, -size.y * 0.25),
      Offset(-size.x * 0.72, -size.y * 0.25),
      _trailPaint,
    );
    canvas.drawLine(
      Offset(-size.x / 2, size.y * 0.25),
      Offset(-size.x * 0.72, size.y * 0.25),
      _trailPaint,
    );

    canvas.restore();
  }
}
