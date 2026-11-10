import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

enum BossState {
  meetingMinions,
  movingToRight,
  waitingRightInvulnerable,
  summoningPhase1,
  combat,
  enragedCombat,
  escaping,
  escaped,
}

enum BossAnimPose { idle, running, punching, kicking, skill, hurt, defeated }

/// Syndicate Warlord / Boss stationed at the Abandoned Warehouse.
class ViperBoss extends PositionComponent with CollisionCallbacks, HasGameReference {
  static const int maxHp = 450;
  int health = maxHp;
  int get maxHealth => maxHp;
  bool get isInvulnerable => bossState == BossState.waitingRightInvulnerable;
  bool get isEnraged => hasTriggeredEnrage;
  BossAnimPose get currentAnim => animPose;
  int get attackDamage => hasTriggeredEnrage ? 36 : 18;

  double patrolDirection = -1.0;
  final double runSpeed = 110.0;
  final double chaseSpeed = 130.0;
  final double groundLevel;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = true;
  WarehousePlatform? currentPlatform;

  BossState bossState = BossState.meetingMinions;
  BossAnimPose animPose = BossAnimPose.idle;

  // Timers and combat cooldowns
  double _hitCooldownTimer = 0.0;
  double _hurtTimer = 0.0;
  double _attackTimer = 0.0;
  double _attackCooldown = 1.3;
  double _jumpCooldown = 0.0;
  double _skillCooldown = 0.0;
  double _webSlowTimer = 0.0;
  double _animTimer = 0.0;
  int _animIndex = 0;

  // Enrage and escape milestone triggers
  bool hasTriggeredEnrage = false;
  bool hasTriggeredEscape = false;
  double _enrageSkillCastTimer = 0.0;

  final math.Random _random = math.Random();

  // Sprites
  final List<Sprite> _idleSprites = [];
  final List<Sprite> _runSprites = [];
  final List<Sprite> _punchSprites = [];
  final List<Sprite> _kickSprites = [];
  final List<Sprite> _skillSprites = [];
  Sprite? _hurtSprite;
  Sprite? _defeatedSprite;

  static const double scaleRefH = 279.0;

  // Cached health bar and shield visual paints
  static final Paint _hpBgPaint = Paint()..color = const Color(0xFF0F172A);
  static final Paint _hpBorderPaint = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _hpGreen = Paint()..color = const Color(0xFF10B981);
  static final Paint _hpYellow = Paint()..color = const Color(0xFFF59E0B);
  static final Paint _hpRed = Paint()..color = const Color(0xFFEF4444);
  static final Paint _hpEnrage = Paint()..color = const Color(0xFFDC2626);

  static final Paint _shieldBarrierPaint = Paint()
    ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
    ..style = PaintingStyle.fill;
  static final Paint _shieldBorderPaint = Paint()
    ..color = const Color(0xFF0284C7).withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final Paint _enrageAuraPaint = Paint()
    ..color = const Color(0xFFEF4444).withValues(alpha: 0.28)
    ..style = PaintingStyle.fill;
  static final Paint _enrageRingPaint = Paint()
    ..color = const Color(0xFFF87171).withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  // Fallback vector paints
  static final Paint _bossArmorPaint = Paint()..color = const Color(0xFF1C1917);
  static final Paint _bossVestPaint = Paint()..color = const Color(0xFF7F1D1D);
  static final Paint _bossVisorPaint = Paint()..color = const Color(0xFFF59E0B);

  ViperBoss({
    required Vector2 position,
    Vector2? size,
    this.groundLevel = 480.0,
  }) : super(
          position: position,
          size: size ?? Vector2(38, 68),
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
        final s = await Sprite.load('story/enemy/boss/idle/$i.png');
        _idleSprites.add(s);
      } catch (_) {}
    }

    // 2. Running frames (1..4)
    _runSprites.clear();
    for (int i = 1; i <= 4; i++) {
      try {
        final s = await Sprite.load('story/enemy/boss/running/$i.png');
        _runSprites.add(s);
      } catch (_) {}
    }

    // 3. Attack punch frames (1..3)
    _punchSprites.clear();
    for (int i = 1; i <= 3; i++) {
      try {
        final s = await Sprite.load('story/enemy/boss/attack/punch/$i.png');
        _punchSprites.add(s);
      } catch (_) {}
    }

    // 4. Attack kick frames (1..2)
    _kickSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('story/enemy/boss/attack/kick/$i.png');
        _kickSprites.add(s);
      } catch (_) {}
    }

    // 5. Attack skill frames (1..2)
    _skillSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('story/enemy/boss/attack/skill/$i.png');
        _skillSprites.add(s);
      } catch (_) {}
    }

    // 6. Hurt frame
    try {
      _hurtSprite = await Sprite.load('story/enemy/boss/hurt/1.png');
    } catch (_) {}

    // 7. Defeated frame
    try {
      _defeatedSprite = await Sprite.load('story/enemy/boss/defeated/1.png');
    } catch (_) {}
  }

  /// Called when Spider-Man makes his first movement/action after the cutscene.
  void onPlayerEngaged() {
    if (bossState == BossState.meetingMinions) {
      bossState = BossState.movingToRight;
      patrolDirection = 1.0;
    }
  }

  /// Web Shot projectile hit: deals damage (unless invulnerable) and applies 0.4s slow
  void hitByWeb(double knockbackDir) {
    if (bossState == BossState.waitingRightInvulnerable || bossState == BossState.escaping) {
      _showImmuneFx();
      return;
    }
    takeDamage(2, knockbackDir);
    _webSlowTimer = 0.4;
  }

  /// Take damage and knockback from Spidey's punches, kicks, and webs
  void takeDamage(int amount, double knockbackDir) {
    if (bossState == BossState.waitingRightInvulnerable ||
        bossState == BossState.escaping ||
        bossState == BossState.escaped ||
        _hitCooldownTimer > 0) {
      if (bossState == BossState.waitingRightInvulnerable) {
        _showImmuneFx();
      }
      return;
    }

    _hitCooldownTimer = 0.20;

    // Phase 2 Enrage Defense: 60% damage reduction when health is half or below!
    int actualDamage = amount;
    if (hasTriggeredEnrage) {
      actualDamage = math.max(1, (amount * 0.40).round());
    }

    health -= actualDamage;
    _hurtTimer = 0.24;
    animPose = BossAnimPose.hurt;

    // Small crisp damage number directly above boss head
    parent?.add(
      DamageNumber(
        amount: actualDamage,
        position: position - Vector2(0, size.y + 16.0),
        color: hasTriggeredEnrage ? const Color(0xFFF87171) : const Color(0xFFFDE047),
      ),
    );

    // MILESTONE 1: Health becomes half (<= 50%) -> Activate Skill (Enrage, Critical Damage & Hard Defense)
    if (!hasTriggeredEnrage && health <= (maxHp * 0.50)) {
      hasTriggeredEnrage = true;
      bossState = BossState.enragedCombat;
      animPose = BossAnimPose.skill;
      _enrageSkillCastTimer = 0.70;
      AudioManager.instance.playPunch();
      return;
    }

    // MILESTONE 2: Health becomes 10% -> Summon 5 minions, run away, and disappear!
    if (!hasTriggeredEscape && health <= (maxHp * 0.10)) {
      hasTriggeredEscape = true;
      bossState = BossState.escaping;
      patrolDirection = 1.0;
      animPose = BossAnimPose.running;
      velocity.x = 240.0;
      _summonMinions(5);
      return;
    }

    if (health <= 0) {
      health = 0;
      bossState = BossState.escaped;
      removeFromParent();
    }
  }

  void _showImmuneFx() {
    parent?.add(
      DamageNumber(
        amount: 0,
        position: position - Vector2(0, size.y + 16.0),
        color: const Color(0xFF38BDF8),
      ),
    );
  }

  /// Summon syndicate minions into the arena
  void _summonMinions(int count) {
    if (parent == null) return;
    AudioManager.instance.playJump();

    final spawnPositions = [
      Vector2(450.0, groundLevel),
      Vector2(750.0, 364.0),
      Vector2(1100.0, 364.0),
      Vector2(1400.0, groundLevel),
      Vector2(1700.0, groundLevel),
    ];

    for (int i = 0; i < count; i++) {
      final pos = spawnPositions[i % spawnPositions.length];
      final minion = ViperGuard(
        position: pos.clone(),
        patrolRange: 180.0,
        groundLevel: groundLevel,
        size: Vector2(28, 50),
        onDefeated: () {
          if (game is WarehouseGame) {
            final wGame = game as WarehouseGame;
            wGame.defeatedGuards++;
            wGame.checkAllMinionsDefeated();
          }
        },
      );
      parent!.add(minion);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_hitCooldownTimer > 0) _hitCooldownTimer -= dt;
    if (_attackCooldown > 0) _attackCooldown -= dt;
    if (_jumpCooldown > 0) _jumpCooldown -= dt;
    if (_webSlowTimer > 0) _webSlowTimer -= dt;
    if (_skillCooldown > 0) _skillCooldown -= dt;

    final speedFactor = _webSlowTimer > 0 ? 0.25 : 1.0;

    // 1. Cutscene meeting state
    if (bossState == BossState.meetingMinions) {
      animPose = BossAnimPose.idle;
      velocity.setZero();
      _updateAnimation(dt, 0.20);
      return;
    }

    // 2. Boss moves to far right when Spider-Man moves, dropping cleanly to the floor
    if (bossState == BossState.movingToRight) {
      animPose = BossAnimPose.running;
      patrolDirection = 1.0;
      velocity.x = runSpeed * 1.5;
      if (position.x > 1380.0 && position.y < groundLevel) {
        currentPlatform = null;
        isGrounded = false;
      }
      if (position.x >= 1860.0) {
        position.x = 1860.0;
        position.y = groundLevel;
        velocity.setZero();
        bossState = BossState.waitingRightInvulnerable;
        animPose = BossAnimPose.idle;
      }
      _applyMovementAndPhysics(dt);
      _updateAnimation(dt, 0.12);
      return;
    }

    // 3. Waiting at far right with invulnerable energy shield until all initial minions are defeated
    if (bossState == BossState.waitingRightInvulnerable) {
      animPose = BossAnimPose.idle;
      velocity.setZero();
      position.y = groundLevel; // Firmly grounded on the floor
      isGrounded = true;
      patrolDirection = -1.0; // Face left towards the arena
      _updateAnimation(dt, 0.25);
      return;
    }

    // 4. All initial minions defeated: Boss leaps down into the combat arena and summons 5 minions!
    if (bossState == BossState.summoningPhase1) {
      _summonMinions(5);
      bossState = BossState.combat;
      velocity.y = -480.0;
      velocity.x = -220.0;
      isGrounded = false;
      currentPlatform = null;
      AudioManager.instance.playJump();
      return;
    }

    // 5. Enrage casting skill animation
    if (_enrageSkillCastTimer > 0) {
      _enrageSkillCastTimer -= dt;
      velocity.setZero();
      animPose = BossAnimPose.skill;
      _updateAnimation(dt, 0.14);
      if (_enrageSkillCastTimer <= 0) {
        animPose = BossAnimPose.running;
      }
      return;
    }

    // 6. Escaping: runs right and disappears
    if (bossState == BossState.escaping) {
      animPose = BossAnimPose.running;
      patrolDirection = 1.0;
      velocity.x = 260.0;
      _applyMovementAndPhysics(dt);
      _updateAnimation(dt, 0.10);
      if (position.x >= 2040.0) {
        bossState = BossState.escaped;
        removeFromParent();
      }
      return;
    }

    // 7. Active Combat & Enraged Combat: chase player, jump between platforms, punch & kick
    if (bossState == BossState.combat || bossState == BossState.enragedCombat) {
      if (_hurtTimer > 0) {
        _hurtTimer -= dt;
        animPose = BossAnimPose.hurt;
        _applyMovementAndPhysics(dt);
        return;
      }

      if (animPose == BossAnimPose.punching || animPose == BossAnimPose.kicking) {
        _attackTimer -= dt;
        _updateAnimation(dt, 0.10);
        if (_attackTimer <= 0) {
          animPose = BossAnimPose.running;
        }
        _applyMovementAndPhysics(dt);
        return;
      }

      if (parent != null && game is WarehouseGame) {
        final player = (game as WarehouseGame).player;
        final dx = player.position.x - position.x;
        final dy = player.position.y - position.y;

        patrolDirection = dx >= 0 ? 1.0 : -1.0;

        // In close range (< 42px horizontal, < 26px vertical): Attack!
        if (dx.abs() < 42.0 && dy.abs() < 26.0) {
          velocity.x = 0;
          if (_attackCooldown <= 0) {
            animPose = _random.nextBool() ? BossAnimPose.punching : BossAnimPose.kicking;
            _attackTimer = 0.35;
            _attackCooldown = hasTriggeredEnrage ? 0.95 : 1.35;
            _animTimer = 0.0;
            _animIndex = 0;
            AudioManager.instance.playPunch();

            // Deal critical damage when enraged!
            final dmg = animPose == BossAnimPose.punching
                ? (hasTriggeredEnrage ? 36 : 18)
                : (hasTriggeredEnrage ? 54 : 28);
            player.takeDamage(dmg);
            return;
          }
        } else {
          final curChaseSpeed = (hasTriggeredEnrage ? (chaseSpeed * 1.25) : chaseSpeed) * speedFactor;
          velocity.x = patrolDirection * curChaseSpeed;
          animPose = BossAnimPose.running;

          if (isGrounded && _jumpCooldown <= 0 && _webSlowTimer <= 0) {
            // Gap jump between platforms
            final isNearLeftEdge = (position.x >= 310.0 && position.x <= 365.0 && patrolDirection > 0);
            final isNearCenterEdge = (position.x >= 615.0 && position.x <= 670.0 && patrolDirection < 0);
            final playerAcrossGap = (position.y < 380.0 && player.position.y < 380.0 &&
                ((position.x < 400.0 && player.position.x > 500.0) ||
                 (position.x > 600.0 && player.position.x < 450.0)));

            if ((isNearLeftEdge || isNearCenterEdge) && playerAcrossGap) {
              velocity.y = -560.0;
              velocity.x = patrolDirection * 360.0;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.8;
              AudioManager.instance.playJump();
            }
            // Jump up to platform from floor
            else if (dy < -30.0 && dx.abs() < 250.0) {
              velocity.y = -630.0;
              velocity.x = patrolDirection * 170.0;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.6;
              AudioManager.instance.playJump();
            }
            // Drop down to floor
            else if (dy > 50.0 && position.y < 400.0) {
              velocity.y = -100.0;
              velocity.x = patrolDirection * curChaseSpeed;
              isGrounded = false;
              currentPlatform = null;
              _jumpCooldown = 1.4;
            }
          }
        }
      }

      _applyMovementAndPhysics(dt);
      _updateAnimation(dt, 0.12);
    }
  }

  void _applyMovementAndPhysics(double dt) {
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
  }

  void _updateAnimation(double dt, double frameDuration) {
    _animTimer += dt;
    int maxFrames = 1;
    switch (animPose) {
      case BossAnimPose.idle:
        maxFrames = _idleSprites.isNotEmpty ? _idleSprites.length : 1;
        break;
      case BossAnimPose.running:
        maxFrames = _runSprites.isNotEmpty ? _runSprites.length : 1;
        break;
      case BossAnimPose.punching:
        maxFrames = _punchSprites.isNotEmpty ? _punchSprites.length : 1;
        break;
      case BossAnimPose.kicking:
        maxFrames = _kickSprites.isNotEmpty ? _kickSprites.length : 1;
        break;
      case BossAnimPose.skill:
        maxFrames = _skillSprites.isNotEmpty ? _skillSprites.length : 1;
        break;
      case BossAnimPose.hurt:
      case BossAnimPose.defeated:
        maxFrames = 1;
        break;
    }
    _animIndex = (_animTimer / frameDuration).floor() % maxFrames;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is WarehousePlatform) {
      final platTop = other.position.y;
      final bossBottom = position.y;
      if (velocity.y >= 0 && bossBottom >= platTop - 6.0 && bossBottom <= platTop + 20.0) {
        position.y = platTop;
        velocity.y = 0;
        isGrounded = true;
        currentPlatform = other;
      }
    }

    if (other is Spidey &&
        bossState != BossState.waitingRightInvulnerable &&
        bossState != BossState.escaping &&
        bossState != BossState.escaped) {
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

    // 1. Invulnerable Shield Barrier Graphic when waiting at the right side
    if (bossState == BossState.waitingRightInvulnerable) {
      final shieldRect = Rect.fromCenter(
        center: Offset(0, -size.y * 0.5),
        width: size.x * 1.5,
        height: size.y * 1.15,
      );
      canvas.drawOval(shieldRect, _shieldBarrierPaint);
      canvas.drawOval(shieldRect, _shieldBorderPaint);
    }

    // 2. Crimson Flame Rage Aura when Enraged (HP <= 50%)
    if (hasTriggeredEnrage && bossState != BossState.escaped) {
      final auraRect = Rect.fromCenter(
        center: Offset(0, -size.y * 0.5),
        width: size.x * 1.6,
        height: size.y * 1.2,
      );
      canvas.drawOval(auraRect, _enrageAuraPaint);
      canvas.drawOval(auraRect, _enrageRingPaint);
    }

    // Flip horizontally when facing left
    if (patrolDirection < 0) {
      canvas.save();
      canvas.scale(-1, 1);
    }

    bool spriteRendered = false;
    final scale = size.y / scaleRefH;

    if (animPose == BossAnimPose.defeated && _defeatedSprite != null) {
      _defeatedSprite!.render(
        canvas,
        position: Vector2(-147.0 * scale, -234.0 * scale),
        size: Vector2(294.0 * scale, 235.0 * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.hurt && _hurtSprite != null) {
      _hurtSprite!.render(
        canvas,
        position: Vector2(-102.0 * scale, -254.0 * scale),
        size: Vector2(204.0 * scale, 255.0 * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.skill && _skillSprites.isNotEmpty) {
      final idx = _animIndex % _skillSprites.length;
      final sprite = _skillSprites[idx];
      final w = idx == 0 ? 176.0 : 236.0;
      final h = idx == 0 ? 313.0 : 295.0;
      sprite.render(
        canvas,
        position: Vector2(-w * 0.5 * scale, -h * scale),
        size: Vector2(w * scale, h * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.punching && _punchSprites.isNotEmpty) {
      final idx = _animIndex % _punchSprites.length;
      final sprite = _punchSprites[idx];
      const widths = [191.0, 223.0, 247.0];
      const heights = [239.0, 278.0, 309.0];
      final w = widths[idx % widths.length];
      final h = heights[idx % heights.length];
      sprite.render(
        canvas,
        position: Vector2(-w * 0.45 * scale, -h * scale),
        size: Vector2(w * scale, h * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.kicking && _kickSprites.isNotEmpty) {
      final idx = _animIndex % _kickSprites.length;
      final sprite = _kickSprites[idx];
      final w = idx == 0 ? 263.0 : 249.0;
      final h = idx == 0 ? 329.0 : 311.0;
      sprite.render(
        canvas,
        position: Vector2(-w * 0.5 * scale, -h * scale),
        size: Vector2(w * scale, h * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.running && _runSprites.isNotEmpty) {
      final idx = _animIndex % _runSprites.length;
      final sprite = _runSprites[idx];
      const widths = [233.0, 212.0, 212.0, 192.0];
      const heights = [291.0, 266.0, 266.0, 241.0];
      final w = widths[idx % widths.length];
      final h = heights[idx % heights.length];
      sprite.render(
        canvas,
        position: Vector2(-w * 0.48 * scale, -h * scale),
        size: Vector2(w * scale, h * scale),
      );
      spriteRendered = true;
    } else if (_idleSprites.isNotEmpty) {
      final idx = _animIndex % _idleSprites.length;
      final sprite = _idleSprites[idx];
      const widths = [157.0, 157.0, 160.0, 157.0, 159.0];
      const heights = [279.0, 279.0, 285.0, 279.0, 283.0];
      final w = widths[idx % widths.length];
      final h = heights[idx % heights.length];
      sprite.render(
        canvas,
        position: Vector2(-w * 0.5 * scale, -h * scale),
        size: Vector2(w * scale, h * scale),
      );
      spriteRendered = true;
    }

    // Vector fallback
    if (!spriteRendered) {
      final w = size.x;
      final h = size.y;
      canvas.drawRect(Rect.fromLTWH(-w * 0.45, -h * 0.45, w * 0.9, h * 0.45), _bossArmorPaint);
      canvas.drawRect(Rect.fromLTWH(-w * 0.5, -h * 0.85, w, h * 0.45), _bossVestPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -h * 0.9), width: w * 0.6, height: h * 0.25), _bossArmorPaint);
      canvas.drawRect(Rect.fromLTWH(w * 0.05, -h * 0.92, w * 0.25, 4), _bossVisorPaint);
    }

    if (patrolDirection < 0) {
      canvas.restore();
    }

    // Overhead Boss Health Bar
    if (bossState != BossState.escaped) {
      const barW = 52.0;
      const barH = 5.0;
      final barY = -size.y - 12.0;
      final hpPct = (health / maxHp).clamp(0.0, 1.0);

      // Dark background container
      final bgRect = Rect.fromCenter(
        center: Offset(0, barY),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(2)), _hpBorderPaint);

      // Fill bar
      if (hpPct > 0) {
        final fillPaint = hasTriggeredEnrage
            ? _hpEnrage
            : (hpPct > 0.5 ? _hpGreen : (hpPct > 0.25 ? _hpYellow : _hpRed));
        final fillRect = Rect.fromLTWH(
          -barW * 0.5 + 1.0,
          barY - (barH * 0.5) + 1.0,
          (barW - 2.0) * hpPct,
          barH - 2.0,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(fillRect, const Radius.circular(1)), fillPaint);
      }
    }
  }
}
