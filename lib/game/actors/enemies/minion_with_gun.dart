import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
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
  Vector2 velocity = Vector2.zero();
  bool isDefeated = false;
  GunMinionState state = GunMinionState.idle;
  bool hasPlayerMoved = false;

  final double _shootCooldown = 2.4;
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
    // In attack/1.png (101x135), the rifle barrel is at y=46 (89px / 66% above the feet)
    final barrelY = position.y - (size.y * (89.0 / 135.0));
    // Barrel extends forward horizontally in the direction the minion is facing
    final offsetDir = isFacingRight ? 1.0 : -1.0;
    final barrelX = position.x + (offsetDir * (size.x * 0.5));
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

    // Platform grounding check & alley fall fatal elimination
    if (currentPlatform != null) {
      final platLeft = currentPlatform!.position.x;
      final platRight = platLeft + currentPlatform!.size.x;
      if (position.x < platLeft - 10.0 || position.x > platRight + 10.0) {
        currentPlatform = null;
      }
    }

    if (currentPlatform == null) {
      velocity.y += 980.0 * dt;
      position.y += velocity.y * dt;
      if (position.y >= groundLevel) {
        position.y = groundLevel;
        isDefeated = true;
        health = 0;
        onDefeated?.call();
        Future.microtask(() {
          if (isMounted) removeFromParent();
        });
        return;
      }
    }

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
          (player.position.y - 414.0).abs() > 6.0 ||
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
        _aimTimer = 0.35; // Slower, readable telegraph to give Spidey time to react
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
      speed: 520.0,
    );
    Future.microtask(() {
      if (parent != null) {
        parent?.add(bullet);
      }
    });

    // Audio SFX
    try {
      AudioManager.instance.playWebShoot();
    } catch (_) {}

    // Return to idle after short snappy recoil
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!isDefeated && state == GunMinionState.shooting) {
        state = GunMinionState.idle;
      }
    });
  }

  /// Whether the marksman is currently shielded because normal guards are still active
  bool get isShielded {
    if (parent == null) return false;
    return parent!.children.whereType<ViperGuard>().any((g) => !g.isDefeated);
  }

  /// Takes combat damage from Spidey punch, kick, or web projectile
  void takeDamage(int amount, [double knockback = 0.0]) {
    if (isDefeated) return;

    // Normal enemies must be defeated first before marksman can take damage
    if (isShielded) {
      AudioManager.instance.playButtonClick();
      final dmgPos = Vector2(position.x, position.y - size.y - 12);
      Future.microtask(() {
        if (parent != null) {
          parent?.add(DamageNumber(
            amount: 0,
            label: 'SHIELDED',
            position: dmgPos,
            color: const Color(0xFF38BDF8),
          ));
        }
      });
      return;
    }

    health = math.max(0, health - amount);

    // Display floating damage number
    final dmgPos = Vector2(position.x, position.y - size.y - 12);
    Future.microtask(() {
      if (parent != null) {
        parent?.add(DamageNumber(amount: amount, position: dmgPos));
      }
    });

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

    // Flip horizontally around the minion's center line
    canvas.translate(size.x * 0.5, 0.0);
    if (!isFacingRight) {
      canvas.scale(-1.0, 1.0);
    }
    canvas.translate(-size.x * 0.5, 0.0);

    bool spriteDrawn = false;

    if (state == GunMinionState.defeated && _defeatedSprite != null) {
      _defeatedSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.2, size.y * 0.55),
        size: Vector2(size.x * 1.4, size.y * 0.45),
      );
      spriteDrawn = true;
    } else if (state == GunMinionState.hurt && _hurtSprite != null) {
      _hurtSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      spriteDrawn = true;
    } else if ((state == GunMinionState.aiming || state == GunMinionState.shooting) &&
        _attackSprite != null) {
      _attackSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      spriteDrawn = true;
    } else if (_idleSprite != null) {
      _idleSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      spriteDrawn = true;
    } else if (_walkSprites.isNotEmpty) {
      _walkSprites.first.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      spriteDrawn = true;
    } else if (_attackSprite != null) {
      _attackSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      spriteDrawn = true;
    }

    // Fallback tactical render if running headless
    if (!spriteDrawn) {
      final bodyPaint = Paint()..color = const Color(0xFF1E293B);
      final gunPaint = Paint()..color = const Color(0xFF94A3B8);
      canvas.drawRect(Rect.fromLTWH(size.x * 0.1, 0, size.x * 0.8, size.y), bodyPaint);
      canvas.drawRect(Rect.fromLTWH(size.x * 0.5, size.y * 0.35, size.x * 0.5, 8), gunPaint);
    }

    // Entangled web visual if slowed
    if (_webSlowTimer > 0 && _webOverlaySprite != null) {
      _webOverlaySprite!.render(
        canvas,
        position: Vector2(5, size.y * 0.3),
        size: Vector2(30, 24),
      );
    }

    canvas.restore();

    // Protective Cyber Shield bubble when marksman is shielded by active guards
    if (!isDefeated && isShielded) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final shieldRect = Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y * 0.5),
        width: size.x * 1.35,
        height: size.y * 1.15,
      );
      canvas.drawOval(shieldRect, shieldPaint);
      canvas.drawOval(shieldRect, borderPaint);

      // "SHIELDED" tag indicator above head
      const shieldTagW = 46.0;
      const shieldTagH = 10.0;
      const tagY = -20.0;
      final tagRect = Rect.fromCenter(
        center: Offset(size.x * 0.5, tagY),
        width: shieldTagW,
        height: shieldTagH,
      );
      final tagBg = Paint()..color = const Color(0xFF0369A1);
      final tagBorder = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(3)), tagBg);
      canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(3)), tagBorder);

      final tp = TextPainter(
        text: const TextSpan(
          text: 'SHIELDED',
          style: TextStyle(
            color: Color(0xFFE0F2FE),
            fontSize: 6.5,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.x * 0.5) - (tp.width / 2), tagY - (tp.height / 2)));
    }

    // Red Health Bar above head
    if (!isDefeated) {
      const barW = 28.0;
      const barH = 4.0;
      const barY = -8.0;
      final hpRatio = (health / maxHp).clamp(0.0, 1.0);

      final bgRect = Rect.fromCenter(
        center: Offset(size.x * 0.5, barY),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBorderPaint);

      final fillW = (barW - 2) * hpRatio;
      if (fillW > 0) {
        final fillRect = Rect.fromLTWH(
          (size.x * 0.5) - (barW / 2) + 1,
          barY - (barH / 2) + 1,
          fillW,
          barH - 2,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(fillRect, const Radius.circular(1)), _hpFillPaint);
      }
    }
  }
}
