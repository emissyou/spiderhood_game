import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/components/gun_bullet.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

enum GunMinionState { idle, patrol, aiming, shooting, hurt, defeated }

/// Marksman minion equipped with a firearm, deployed exclusively on the final rooftop
/// of Moonlit Rooftop Cityscape.
class MinionWithGun extends PositionComponent with CollisionCallbacks, HasGameReference {
  static const int maxHp = 72; // 4 punches (18 dmg) to defeat
  int health = maxHp;

  bool isFacingRight = false;
  final double groundLevel;
  final VoidCallback? onDefeated;

  WarehousePlatform? currentPlatform;
  bool isDefeated = false;
  GunMinionState state = GunMinionState.idle;
  bool hasPlayerMoved = false;

  final double _shootCooldown = 2.0;
  double _shootTimer = 0.0;
  double _aimTimer = 0.0;
  double _hurtTimer = 0.0;
  double _webSlowTimer = 0.0;

  // Sprites
  Sprite? _idleSprite;
  Sprite? _attackSprite;
  final List<Sprite> _walkSprites = [];
  Sprite? _hurtSprite;
  Sprite? _defeatedSprite;
  Sprite? _webOverlaySprite;

  static final Paint _hpBgPaint = Paint()..color = const Color(0xFF0F172A);
  static final Paint _hpBorderPaint = Paint()
    ..color = Colors.white38
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _hpFillPaint = Paint()..color = const Color(0xFFEF4444);

  MinionWithGun({
    required Vector2 position,
    required this.groundLevel,
    double minPatrolX = 2010.0,
    double maxPatrolX = 2150.0,
    this.onDefeated,
  }) : super(
          position: position,
          size: Vector2(40, 56),
          anchor: Anchor.bottomCenter,
        );

  /// Precise gun barrel tip coordinate from which bullets emerge
  Vector2 get gunBarrelPosition {
    // Barrel is located at ~70.4% character height above the feet
    final barrelY = position.y - (size.y * 0.704);
    // Barrel extends forward horizontally in the direction the minion is facing
    final offsetDir = isFacingRight ? 1.0 : -1.0;
    final barrelX = position.x + (offsetDir * (size.x * 0.65));
    return Vector2(barrelX, barrelY);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      position: Vector2(size.x * 0.15, 0),
      size: Vector2(size.x * 0.7, size.y),
    ));

    // Load Minion With Gun sprites
    try {
      _idleSprite = await Sprite.load('enemies/minion_wgun/walk/1.png');
    } catch (_) {}

    try {
      _attackSprite = await Sprite.load('enemies/minion_wgun/attack/1.png');
    } catch (_) {}

    try {
      _walkSprites.add(await Sprite.load('enemies/minion_wgun/walk/1.png'));
      _walkSprites.add(await Sprite.load('enemies/minion_wgun/walk/2.png'));
      _walkSprites.add(await Sprite.load('enemies/minion_wgun/walk/3.png'));
    } catch (_) {}

    try {
      _hurtSprite = await Sprite.load('enemies/minion_wgun/hurt/1.png');
    } catch (_) {}

    try {
      _defeatedSprite = await Sprite.load('enemies/minion_wgun/defeated/1.png');
    } catch (_) {}

    try {
      _webOverlaySprite = await Sprite.load('player/web_swing/1.png');
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isDefeated) return;

    // Web slow / freeze decay
    if (_webSlowTimer > 0) {
      _webSlowTimer -= dt;
      return;
    }

    // Hurt animation decay
    if (state == GunMinionState.hurt) {
      _hurtTimer -= dt;
      if (_hurtTimer <= 0) {
        state = GunMinionState.idle;
      }
      return;
    }

    // Query player for targeting
    final player = parent?.children.whereType<Spidey>().firstOrNull;
    if (player == null || player.isDefeated) {
      state = GunMinionState.idle;
      return;
    }

    // Face towards player wherever they are on the rooftops
    isFacingRight = player.position.x > position.x;

    // Detect initial player movement to awaken marksman
    if (!hasPlayerMoved) {
      final moved = (player.position.x - 80.0).abs() > 4.0 ||
          (player.position.y - 424.0).abs() > 4.0 ||
          player.velocity.length > 5.0 ||
          player.state != SpideyState.idle;
      if (moved) {
        hasPlayerMoved = true;
        // The moment player moves, start shooting right away!
        _shootTimer = _shootCooldown;
      }
    }

    // Only shoot after player initiates movement
    if (hasPlayerMoved) {
      _shootTimer += dt;
      if (state == GunMinionState.idle && _shootTimer >= _shootCooldown) {
        state = GunMinionState.aiming;
        _aimTimer = 0.40; // 0.4s telegraph to let player anticipate shot
      } else if (state == GunMinionState.aiming) {
        _aimTimer -= dt;
        if (_aimTimer <= 0) {
          _fireBulletAtPlayer(player);
        }
      }
    }
  }

  void _fireBulletAtPlayer(Spidey player) {
    state = GunMinionState.shooting;
    _shootTimer = 0.0;

    // Aim at player's body center wherever player is moving
    final targetCenter = Vector2(
      player.position.x,
      player.position.y - (player.size.y * 0.45),
    );

    // Spawn projectile exactly at the gun barrel tip directed towards player
    final bullet = GunBullet(
      position: gunBarrelPosition,
      targetPosition: targetCenter,
      direction: isFacingRight ? 1.0 : -1.0,
      speed: 460.0,
    );
    parent?.add(bullet);

    // Audio SFX
    try {
      AudioManager.instance.playWebShoot();
    } catch (_) {}

    // Return to idle after short recoil
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!isDefeated && state == GunMinionState.shooting) {
        state = GunMinionState.idle;
      }
    });
  }

  /// Takes combat damage from Spidey punch, kick, or web projectile
  void takeDamage(int amount, [double knockback = 0.0]) {
    if (isDefeated) return;

    health = math.max(0, health - amount);

    // Display floating damage number
    final dmgPos = Vector2(position.x, position.y - size.y - 12);
    parent?.add(DamageNumber(amount: amount, position: dmgPos));

    if (health <= 0) {
      isDefeated = true;
      state = GunMinionState.defeated;
      onDefeated?.call();
    } else {
      state = GunMinionState.hurt;
      _hurtTimer = 0.32;
      position.x += knockback * 16.0;
    }
  }

  /// Hits from Spidey's WebAmmo projectile
  void hitByWeb(double dir) {
    takeDamage(35, dir);
    _webSlowTimer = 1.4;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // The raw sprite artwork points to the right; if minion faces left, flip horizontally
    if (!isFacingRight) {
      canvas.scale(-1.0, 1.0);
    }

    bool spriteDrawn = false;

    if (state == GunMinionState.defeated && _defeatedSprite != null) {
      _defeatedSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.7, -size.y * 0.45),
        size: Vector2(size.x * 1.4, size.y * 0.45),
      );
      spriteDrawn = true;
    } else if (state == GunMinionState.hurt && _hurtSprite != null) {
      _hurtSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y),
        size: Vector2(size.x, size.y),
      );
      spriteDrawn = true;
    } else if ((state == GunMinionState.aiming || state == GunMinionState.shooting) &&
        _attackSprite != null) {
      _attackSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y),
        size: Vector2(size.x, size.y),
      );
      spriteDrawn = true;
    } else if (_idleSprite != null) {
      _idleSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y),
        size: Vector2(size.x, size.y),
      );
      spriteDrawn = true;
    } else if (_walkSprites.isNotEmpty) {
      _walkSprites.first.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y),
        size: Vector2(size.x, size.y),
      );
      spriteDrawn = true;
    } else if (_attackSprite != null) {
      _attackSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y),
        size: Vector2(size.x, size.y),
      );
      spriteDrawn = true;
    }

    // Fallback tactical render if running headless
    if (!spriteDrawn) {
      final bodyPaint = Paint()..color = const Color(0xFF1E293B);
      final gunPaint = Paint()..color = const Color(0xFF94A3B8);
      canvas.drawRect(Rect.fromLTWH(-size.x * 0.4, -size.y, size.x * 0.8, size.y), bodyPaint);
      canvas.drawRect(Rect.fromLTWH(0, -size.y * 0.75, size.x * 0.7, 8), gunPaint);
    }

    // Entangled web visual if slowed
    if (_webSlowTimer > 0 && _webOverlaySprite != null) {
      _webOverlaySprite!.render(
        canvas,
        position: Vector2(-15, -size.y * 0.7),
        size: Vector2(30, 24),
      );
    }

    canvas.restore();

    // Red Health Bar above head
    if (!isDefeated) {
      const barW = 28.0;
      const barH = 4.0;
      final barY = -size.y - 8.0;
      final hpRatio = (health / maxHp).clamp(0.0, 1.0);

      final bgRect = Rect.fromCenter(
        center: Offset(0, barY),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBorderPaint);

      final fillW = (barW - 2) * hpRatio;
      if (fillW > 0) {
        final fillRect = Rect.fromLTWH(
          -barW / 2 + 1,
          barY - (barH / 2) + 1,
          fillW,
          barH - 2,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(fillRect, const Radius.circular(1)), _hpFillPaint);
      }
    }
  }
}
