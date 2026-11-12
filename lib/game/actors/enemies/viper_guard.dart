import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

enum MinionState { idle, running, punching, kicking, hurt, defeated }

class _MinionFrameData {
  final double imgW;
  final double imgH;
  final double centerX;
  final double feetY;
  final double scaleRefH;

  const _MinionFrameData({
    required this.imgW,
    required this.imgH,
    required this.centerX,
    required this.feetY,
    required this.scaleRefH,
  });
}

/// Armed syndicate minion / Viper Guard stationed in the Abandoned Warehouse.
class ViperGuard extends PositionComponent with CollisionCallbacks, HasGameReference {
  // 126 HP = exactly 7 punches (18 dmg each) to defeat
  static const int maxHp = 126;
  int health = maxHp;

  double patrolDirection = 1.0;
  final double patrolSpeed = 75.0;
  final double chaseSpeed = 95.0;
  final double patrolRange;
  final double originX;
  final double groundLevel;
  final VoidCallback? onDefeated;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = true;
  bool isDefeated = false;
  WarehousePlatform? currentPlatform;
  double _hitCooldownTimer = 0.0;
  double _hurtTimer = 0.0;
  double _attackTimer = 0.0;
  double _attackCooldown = 1.4;
  double _jumpCooldown = 0.0;
  double _webSlowTimer = 0.0;
  double _animTimer = 0.0;
  int _animIndex = 0;
  final math.Random _random = math.Random();

  MinionState state = MinionState.running;

  // Custom Minion sprite assets
  final List<Sprite> _idleSprites = [];
  final List<Sprite> _runSprites = [];
  final List<Sprite> _punchSprites = [];
  final List<Sprite> _kickSprites = [];
  Sprite? _hurtSprite;
  Sprite? _defeatedSprite;
  Sprite? _webOverlaySprite;

  static const List<_MinionFrameData> _idleData = [
    _MinionFrameData(imgW: 77, imgH: 138, centerX: 33.0, feetY: 136.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 71, imgH: 127, centerX: 34.0, feetY: 126.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 72, imgH: 128, centerX: 34.5, feetY: 126.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 71, imgH: 127, centerX: 33.5, feetY: 125.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 71, imgH: 127, centerX: 34.0, feetY: 125.0, scaleRefH: 126.0),
  ];

  static const List<_MinionFrameData> _runData = [
    _MinionFrameData(imgW: 108, imgH: 135, centerX: 53.5, feetY: 122.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 98, imgH: 123, centerX: 48.5, feetY: 121.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 92, imgH: 115, centerX: 45.5, feetY: 112.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 93, imgH: 116, centerX: 46.5, feetY: 111.0, scaleRefH: 126.0),
  ];

  static const List<_MinionFrameData> _punchData = [
    _MinionFrameData(imgW: 86, imgH: 108, centerX: 37.5, feetY: 106.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 83, imgH: 104, centerX: 39.0, feetY: 103.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 88, imgH: 110, centerX: 44.5, feetY: 107.0, scaleRefH: 126.0),
  ];

  static const List<_MinionFrameData> _kickData = [
    _MinionFrameData(imgW: 122, imgH: 153, centerX: 59.5, feetY: 149.0, scaleRefH: 126.0),
    _MinionFrameData(imgW: 110, imgH: 137, centerX: 54.5, feetY: 136.0, scaleRefH: 126.0),
  ];

  static const _MinionFrameData _hurtData =
      _MinionFrameData(imgW: 82, imgH: 103, centerX: 39.0, feetY: 101.0, scaleRefH: 126.0);

  static const _MinionFrameData _defeatedData =
      _MinionFrameData(imgW: 181, imgH: 145, centerX: 90.5, feetY: 123.0, scaleRefH: 126.0);

  // Cached health bar paints
  static final Paint _hpBgPaint = Paint()..color = const Color(0xFF0F172A);
  static final Paint _hpBorderPaint = Paint()
    ..color = const Color(0xFF334155)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _hpRed = Paint()..color = const Color(0xFFEF4444);

  // Fallback vector paints
  static final Paint _armorPaint = Paint()..color = const Color(0xFF0F292F);
  static final Paint _vestPaint = Paint()..color = const Color(0xFF164E63);
  static final Paint _visorPaint = Paint()..color = const Color(0xFF10B981);
  static final Paint _beltPaint = Paint()..color = const Color(0xFF022C22);

  ViperGuard({
    required Vector2 position,
    Vector2? size,
    this.patrolRange = 160.0,
    this.groundLevel = 480.0,
    this.onDefeated,
  })  : originX = position.x,
        super(
          position: position,
          size: size ?? Vector2(28, 50),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    // 1. Idle frames (1..5)
    _idleSprites.clear();
    for (int i = 1; i <= 5; i++) {
      try {
        final s = await Sprite.load('story/enemy/minion/idle/$i.png');
        _idleSprites.add(s);
      } catch (_) {}
    }

    // 2. Running frames (1..4)
    _runSprites.clear();
    for (int i = 1; i <= 4; i++) {
      try {
        final s = await Sprite.load('story/enemy/minion/running/$i.png');
        _runSprites.add(s);
      } catch (_) {}
    }

    // 3. Attack punch frames (1..3)
    _punchSprites.clear();
    for (int i = 1; i <= 3; i++) {
      try {
        final s = await Sprite.load('story/enemy/minion/attack/punch/$i.png');
        _punchSprites.add(s);
      } catch (_) {}
    }

    // 4. Attack kick frames (1..2)
    _kickSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('story/enemy/minion/attack/kick/$i.png');
        _kickSprites.add(s);
      } catch (_) {}
    }

    // 5. Hurt frame
    try {
      _hurtSprite = await Sprite.load('story/enemy/minion/hurt/1.png');
    } catch (_) {}

    // 6. Defeated frame
    try {
      _defeatedSprite = await Sprite.load('story/enemy/minion/defeated/1.png');
    } catch (_) {}

    // 7. Sticky web overlay asset
    try {
      _webOverlaySprite = await Sprite.load('player/web_swing/4.png');
    } catch (_) {}
  }

  /// Called when struck by Spidey's Web Shot: deals 2 damage and slows minion for 0.4s
  void hitByWeb(double knockbackDir) {
    if (isDefeated) return;
    takeDamage(2, knockbackDir);
    _webSlowTimer = 0.4;
  }

  /// Take damage and knockback from Spidey's attacks (clean small damage number, no comic badges)
  void takeDamage(int amount, double knockbackDir) {
    if (isDefeated || _hitCooldownTimer > 0) return;
    _hitCooldownTimer = 0.22;
    state = MinionState.hurt;
    _hurtTimer = 0.30;
    currentPlatform = null;

    health -= amount;
    velocity.x = knockbackDir * 240.0;
    velocity.y = -160.0;
    isGrounded = false;

    // Small, clean floating damage number directly above the enemy head
    parent?.add(
      DamageNumber(
        amount: amount,
        position: position - Vector2(0, size.y + 14.0),
        color: amount >= 30 ? const Color(0xFFF59E0B) : const Color(0xFFFDE047),
      ),
    );

    if (health <= 0) {
      isDefeated = true;
      state = MinionState.defeated;
      currentPlatform = null;
      velocity.x = knockbackDir * 80.0;
      velocity.y = -60.0;
      onDefeated?.call();
      Future.delayed(const Duration(milliseconds: 800), () {
        removeFromParent();
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_hitCooldownTimer > 0) {
      _hitCooldownTimer -= dt;
    }
    if (_attackCooldown > 0) {
      _attackCooldown -= dt;
    }
    if (_jumpCooldown > 0) {
      _jumpCooldown -= dt;
    }
    if (_webSlowTimer > 0) {
      _webSlowTimer -= dt;
    }

    if (isDefeated) {
      velocity.y += GameConfig.gravity.y * dt;
      position += velocity * dt;
      if (position.y >= groundLevel) {
        position.y = groundLevel;
        velocity.setZero();
      }
      return;
    }

    if (state == MinionState.hurt) {
      _hurtTimer -= dt;
      velocity.y += GameConfig.gravity.y * dt;
      position += velocity * dt;
      if (position.y >= groundLevel) {
        position.y = groundLevel;
        velocity.setZero();
        isGrounded = true;
      }
      if (_hurtTimer <= 0) {
        state = MinionState.running;
      }
      return;
    }

    if (state == MinionState.punching || state == MinionState.kicking) {
      _attackTimer -= dt;
      _animTimer += dt;
      const frameDuration = 0.10;
      final maxFrames = state == MinionState.punching ? _punchSprites.length : _kickSprites.length;
      if (maxFrames > 0) {
        _animIndex = (_animTimer / frameDuration).floor() % maxFrames;
      }
      if (_attackTimer <= 0) {
        state = MinionState.running;
        _animTimer = 0.0;
        _animIndex = 0;
      }
      return;
    }

    // Speed multiplier: 20% speed while web slowed
    final speedFactor = _webSlowTimer > 0 ? 0.20 : 1.0;

    // Intelligent AI: follow / chase the player, jump to platform, and attack
    bool chasingPlayer = false;
    if (parent != null && game is WarehouseGame) {
      final warehouse = game as WarehouseGame;
      final player = warehouse.player;
      final dx = player.position.x - position.x;
      final dy = player.position.y - position.y; // Negative if player is on a higher level

      // At start, all minions are lined up facing the boss and not moving
      // They only break formation and move when the player gets close or attacks
      if (!warehouse.hasPlayerEngaged) {
        velocity.x = 0;
        state = MinionState.idle;
        if (dx.abs() < 260.0 && dy.abs() < 180.0 && !warehouse.isEntranceCutscene) {
          warehouse.engagePlayer();
        }
      } else if (!warehouse.isEntranceCutscene &&
          (warehouse.hasPlayerEngaged || warehouse.boss.hasTriggeredEscape || dx.abs() < 600.0)) {
        chasingPlayer = true;
        patrolDirection = dx >= 0 ? 1.0 : -1.0;

        // If in close attack range (< 44px horizontally and < 28px vertically): Attack!
        if (dx.abs() < 44.0 && dy.abs() < 28.0) {
          velocity.x = 0;
          if (_attackCooldown <= 0) {
            state = _random.nextBool() ? MinionState.punching : MinionState.kicking;
            _attackTimer = 0.32;
            _attackCooldown = 1.1;
            _animTimer = 0.0;
            _animIndex = 0;
            AudioManager.instance.playPunch();
            player.takeDamage(1); // Solid hit on player (takes damage even when standing still!)
            return;
          }
        } else {
          // Move towards player
          velocity.x = patrolDirection * chaseSpeed * speedFactor;
          state = MinionState.running;

          if (isGrounded && _jumpCooldown <= 0 && _webSlowTimer <= 0) {
            // 1. GAP JUMP BETWEEN PLATFORMS:
            // Left platform ends at x=360 (y=320), Center bridge starts at x=620 (y=364)
            // Center bridge + right walkway are now joined (x=620..2010 at y=364) — no gap needed there
            final isNearLeftEdge = (position.x >= 310.0 && position.x <= 365.0 && patrolDirection > 0);
            final isNearCenterEdge = (position.x >= 615.0 && position.x <= 670.0 && patrolDirection < 0);
            final playerAcrossGap = (position.y < 420.0 && player.position.y < 420.0 &&
                ((position.x < 400.0 && player.position.x > 500.0) ||
                 (position.x > 600.0 && player.position.x < 450.0)));

            if ((isNearLeftEdge || isNearCenterEdge) && playerAcrossGap) {
              velocity.y = isNearCenterEdge ? -580.0 : -520.0;
              velocity.x = patrolDirection * 360.0;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.8;
              AudioManager.instance.playJump();
            }
            // 2. JUMP TO PLATFORM FROM FLOOR:
            else if (dy < -30.0 && dx.abs() < 240.0) {
              velocity.y = player.position.y < 340.0 ? -700.0 : -630.0;
              velocity.x = patrolDirection * 170.0;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.6;
              AudioManager.instance.playJump();
            }
            // 3. JUMP / DROP DOWN TO FLOOR:
            else if (dy > 50.0 && position.y < 400.0) {
              velocity.y = -100.0;
              velocity.x = patrolDirection * chaseSpeed * speedFactor;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.4;
            }
          }
        }
      }
    }

    // Normal patrol logic if not actively chasing
    if (!chasingPlayer) {
      if (parent != null && game is WarehouseGame && !(game as WarehouseGame).hasPlayerEngaged) {
        velocity.x = 0;
        state = MinionState.idle;
      } else {
        if ((position.x - originX).abs() > patrolRange) {
          patrolDirection = position.x > originX ? -1.0 : 1.0;
        }
        velocity.x = patrolDirection * patrolSpeed * speedFactor;
        state = MinionState.running;
      }
    }

    // Platform grounding check
    if (currentPlatform != null) {
      final platLeft = currentPlatform!.position.x;
      final platRight = platLeft + currentPlatform!.size.x;
      if (position.x >= platLeft - 8.0 && position.x <= platRight + 8.0 && velocity.y >= 0) {
        position.y = currentPlatform!.position.y;
        velocity.y = 0;
        isGrounded = true;
      } else {
        currentPlatform = null;
        isGrounded = false;
      }
    }

    if (!isGrounded) {
      velocity.y += GameConfig.gravity.y * dt;
    }

    position += velocity * dt;

    if (position.y >= groundLevel) {
      position.y = groundLevel;
      velocity.y = 0;
      isGrounded = true;
      currentPlatform = null;
    }

    // Idle and running animation cycle
    _animTimer += dt;
    final frameDuration = state == MinionState.idle
        ? 0.22
        : (_webSlowTimer > 0 ? 0.35 : 0.13);
    final spriteCount = state == MinionState.idle
        ? _idleSprites.length
        : _runSprites.length;
    if (spriteCount > 0) {
      _animIndex = (_animTimer / frameDuration).floor() % spriteCount;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is WarehousePlatform) {
      final platTop = other.position.y;
      final guardBottom = position.y;
      // Land on top of platform surface cleanly
      if (velocity.y >= 0 && guardBottom >= platTop - 6.0 && guardBottom <= platTop + 20.0) {
        position.y = platTop;
        velocity.y = 0;
        isGrounded = true;
        currentPlatform = other;
      }
    }

    if (other is Spidey && !isDefeated) {
      if (other.state == SpideyState.attacking) {
        final dir = other.isFacingRight ? 1.0 : -1.0;
        takeDamage(18, dir);
      } else if (other.state == SpideyState.kicking) {
        final dir = other.isFacingRight ? 1.0 : -1.0;
        takeDamage(32, dir);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // Flip horizontally when moving or facing left
    if (patrolDirection < 0) {
      canvas.scale(-1, 1);
    }

    // Render Minion sprite frames
    bool spriteRendered = false;

    if (state == MinionState.defeated && _defeatedSprite != null) {
      final scale = size.y / _defeatedData.scaleRefH;
      _defeatedSprite!.render(
        canvas,
        position: Vector2(-_defeatedData.centerX * scale, -_defeatedData.feetY * scale),
        size: Vector2(_defeatedData.imgW * scale, _defeatedData.imgH * scale),
      );
      spriteRendered = true;
    } else if (state == MinionState.hurt && _hurtSprite != null) {
      final scale = size.y / _hurtData.scaleRefH;
      _hurtSprite!.render(
        canvas,
        position: Vector2(-_hurtData.centerX * scale, -_hurtData.feetY * scale),
        size: Vector2(_hurtData.imgW * scale, _hurtData.imgH * scale),
      );
      spriteRendered = true;
    } else if (state == MinionState.punching && _punchSprites.isNotEmpty) {
      final idx = _animIndex % _punchSprites.length;
      final data = idx < _punchData.length ? _punchData[idx] : _punchData[0];
      final scale = size.y / data.scaleRefH;
      _punchSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (state == MinionState.kicking && _kickSprites.isNotEmpty) {
      final idx = _animIndex % _kickSprites.length;
      final data = idx < _kickData.length ? _kickData[idx] : _kickData[0];
      final scale = size.y / data.scaleRefH;
      _kickSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (state == MinionState.running && _runSprites.isNotEmpty) {
      final idx = _animIndex % _runSprites.length;
      final data = idx < _runData.length ? _runData[idx] : _runData[0];
      final scale = size.y / data.scaleRefH;
      _runSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (_idleSprites.isNotEmpty) {
      final idx = _animIndex % _idleSprites.length;
      final data = idx < _idleData.length ? _idleData[idx] : _idleData[0];
      final scale = size.y / data.scaleRefH;
      _idleSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    }

    // Fallback tactical vector render if sprite is unavailable (e.g. headless tests)
    if (!spriteRendered) {
      final w = size.x;
      final h = size.y;

      // Legs / Pants
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.45, -h * 0.42, w * 0.9, h * 0.42),
          const Radius.circular(3),
        ),
        _armorPaint,
      );

      // Torso / Tactical vest
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.5, -h * 0.82, w, h * 0.42),
          const Radius.circular(4),
        ),
        _vestPaint,
      );

      // Utility belt
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.52, -h * 0.46, w * 1.04, 4),
        _beltPaint,
      );

      // Helmet & Visor
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.38, -h, w * 0.76, h * 0.22),
          const Radius.circular(4),
        ),
        _armorPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05, -h * 0.93, w * 0.32, 4),
          const Radius.circular(1.5),
        ),
        _visorPaint,
      );
    }

    // Render sticky web asset entangled across minion's body while slowed
    if (_webSlowTimer > 0) {
      if (_webOverlaySprite != null) {
        _webOverlaySprite!.render(
          canvas,
          position: Vector2(-15, -size.y * 0.70),
          size: Vector2(30, 24),
        );
      }
    }

    canvas.restore();

    // Clean, crisp Health Bar above the enemy's head
    if (!isDefeated) {
      const barW = 30.0;
      const barH = 4.0;
      final barY = -size.y - 8.0;
      final hpPct = (health / maxHp).clamp(0.0, 1.0);

      // Dark background container
      final bgRect = Rect.fromCenter(
        center: Offset(0, barY),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
        _hpBgPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
        _hpBorderPaint,
      );

      // Health fill bar
      if (hpPct > 0) {
        final fillPaint = _hpRed;
        final fillRect = Rect.fromLTWH(
          -barW * 0.5 + 1.0,
          barY - (barH * 0.5) + 1.0,
          (barW - 2.0) * hpPct,
          barH - 2.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(fillRect, const Radius.circular(1)),
          fillPaint,
        );
      }
    }
  }
}
