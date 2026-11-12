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

class _BossFrameData {
  final double imgW;
  final double imgH;
  final double centerX;
  final double feetY;
  final double scaleRefH;
  const _BossFrameData({
    required this.imgW,
    required this.imgH,
    required this.centerX,
    required this.feetY,
    required this.scaleRefH,
  });
}

/// Syndicate Warlord / Boss stationed at the Abandoned Warehouse.
class ViperBoss extends PositionComponent with CollisionCallbacks, HasGameReference {
  static const int maxHp = 700;
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
  double _attackCooldown = 0.95;
  double _jumpCooldown = 0.0;
  double _skillCooldown = 0.0;
  double _webSlowTimer = 0.0;
  double _animTimer = 0.0;
  int _animIndex = 0;

  // Enrage and escape milestone triggers
  bool hasTriggeredEnrage = false;
  bool hasTriggeredEscape = false;
  double _enrageSkillCastTimer = 0.0;

  /// True while the escape-wave minions have been summoned but not yet mounted in the world tree.
  /// Prevents the escape scenario from triggering for 1 frame before the new minions are visible.
  bool escapeMinionsPending = false;

  final math.Random _random = math.Random();

  // Sprites
  final List<Sprite> _idleSprites = [];
  final List<Sprite> _runSprites = [];
  final List<Sprite> _punchSprites = [];
  final List<Sprite> _kickSprites = [];
  final List<Sprite> _skillSprites = [];
  Sprite? _hurtSprite;
  Sprite? _defeatedSprite;
  Sprite? _webOverlaySprite;

  static const List<_BossFrameData> _idleData = [
    _BossFrameData(imgW: 157, imgH: 279, centerX: 76.5, feetY: 269.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 157, imgH: 279, centerX: 76.5, feetY: 271.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 160, imgH: 285, centerX: 73.5, feetY: 273.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 157, imgH: 279, centerX: 73.5, feetY: 271.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 159, imgH: 283, centerX: 78.5, feetY: 276.0, scaleRefH: 279.0),
  ];

  static const List<_BossFrameData> _runData = [
    _BossFrameData(imgW: 233, imgH: 291, centerX: 118.0, feetY: 262.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 212, imgH: 266, centerX: 105.5, feetY: 258.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 212, imgH: 266, centerX: 106.5, feetY: 265.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 192, imgH: 241, centerX: 95.5, feetY: 240.0, scaleRefH: 279.0),
  ];

  static const List<_BossFrameData> _punchData = [
    _BossFrameData(imgW: 191, imgH: 239, centerX: 95.0, feetY: 238.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 223, imgH: 278, centerX: 111.0, feetY: 276.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 247, imgH: 309, centerX: 123.0, feetY: 308.0, scaleRefH: 279.0),
  ];

  static const List<_BossFrameData> _kickData = [
    _BossFrameData(imgW: 263, imgH: 329, centerX: 130.5, feetY: 328.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 249, imgH: 311, centerX: 128.5, feetY: 300.0, scaleRefH: 279.0),
  ];

  static const List<_BossFrameData> _skillData = [
    _BossFrameData(imgW: 176, imgH: 313, centerX: 95.0, feetY: 312.0, scaleRefH: 279.0),
    _BossFrameData(imgW: 236, imgH: 295, centerX: 117.5, feetY: 293.0, scaleRefH: 279.0),
  ];

  static const _BossFrameData _hurtData =
      _BossFrameData(imgW: 204, imgH: 255, centerX: 104.0, feetY: 254.0, scaleRefH: 279.0);

  static const _BossFrameData _defeatedData =
      _BossFrameData(imgW: 294, imgH: 235, centerX: 146.5, feetY: 203.0, scaleRefH: 279.0);

  static const double scaleRefH = 279.0;

  // Cached health bar and shield visual paints
  static final Paint _hpBgPaint = Paint()..color = const Color(0xFF0F172A);
  static final Paint _hpBorderPaint = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
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

    // 8. Sticky web overlay asset
    try {
      _webOverlaySprite = await Sprite.load('player/web_swing/4.png');
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

    // Tough boss armor: 25% passive reduction in Phase 1, 65% reduction when Enraged (HP <= 50%)!
    int actualDamage = (amount * 0.75).round();
    if (hasTriggeredEnrage) {
      actualDamage = math.max(1, (amount * 0.35).round());
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
      escapeMinionsPending = true;
      _summonMinions(5);
      // Allow the minions to be mounted before escape can be triggered
      Future.microtask(() { escapeMinionsPending = false; });
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
      Vector2(680.0, 365.0),
      Vector2(880.0, 365.0),
      Vector2(1100.0, 365.0),
      Vector2(1450.0, groundLevel),
      Vector2(1650.0, groundLevel),
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

    // 2. Boss moves to far right when Spider-Man moves, dropping to the floor in the right terminal sector
    if (bossState == BossState.movingToRight) {
      animPose = BossAnimPose.running;
      patrolDirection = 1.0;
      velocity.x = 210.0;
      // When boss passes bridge end (x>1280) drop to floor since there is no elevated platform there
      if (position.x > 1280.0) {
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
      position.y = groundLevel; // Firmly grounded on the floor in the right terminal sector
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
      _applyMovementAndPhysics(dt);
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
            _applyMovementAndPhysics(dt);
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
      if (velocity.y >= 0 && bossBottom >= platTop - 12.0 && bossBottom <= platTop + 24.0) {
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

    canvas.save();
    // Offset slightly downwards (+13.0px) so boss boots align firmly with minion and player feet line
    canvas.translate(0, 13.0);

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
      canvas.scale(-1, 1);
    }

    bool spriteRendered = false;

    if (animPose == BossAnimPose.defeated && _defeatedSprite != null) {
      final scale = size.y / _defeatedData.scaleRefH;
      _defeatedSprite!.render(
        canvas,
        position: Vector2(-_defeatedData.centerX * scale, -_defeatedData.feetY * scale),
        size: Vector2(_defeatedData.imgW * scale, _defeatedData.imgH * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.hurt && _hurtSprite != null) {
      final scale = size.y / _hurtData.scaleRefH;
      _hurtSprite!.render(
        canvas,
        position: Vector2(-_hurtData.centerX * scale, -_hurtData.feetY * scale),
        size: Vector2(_hurtData.imgW * scale, _hurtData.imgH * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.skill && _skillSprites.isNotEmpty) {
      final idx = _animIndex % _skillSprites.length;
      final data = idx < _skillData.length ? _skillData[idx] : _skillData[0];
      final scale = size.y / data.scaleRefH;
      _skillSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.punching && _punchSprites.isNotEmpty) {
      final idx = _animIndex % _punchSprites.length;
      final data = idx < _punchData.length ? _punchData[idx] : _punchData[0];
      final scale = size.y / data.scaleRefH;
      _punchSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.kicking && _kickSprites.isNotEmpty) {
      final idx = _animIndex % _kickSprites.length;
      final data = idx < _kickData.length ? _kickData[idx] : _kickData[0];
      final scale = size.y / data.scaleRefH;
      _kickSprites[idx].render(
        canvas,
        position: Vector2(-data.centerX * scale, -data.feetY * scale),
        size: Vector2(data.imgW * scale, data.imgH * scale),
      );
      spriteRendered = true;
    } else if (animPose == BossAnimPose.running && _runSprites.isNotEmpty) {
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

    // Vector fallback
    if (!spriteRendered) {
      final w = size.x;
      final h = size.y;
      canvas.drawRect(Rect.fromLTWH(-w * 0.45, -h * 0.45, w * 0.9, h * 0.45), _bossArmorPaint);
      canvas.drawRect(Rect.fromLTWH(-w * 0.5, -h * 0.85, w, h * 0.45), _bossVestPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -h * 0.9), width: w * 0.6, height: h * 0.25), _bossArmorPaint);
      canvas.drawRect(Rect.fromLTWH(w * 0.05, -h * 0.92, w * 0.25, 4), _bossVisorPaint);
    }

    // Render sticky web asset entangled across boss body while slowed
    if (_webSlowTimer > 0 && _webOverlaySprite != null) {
      _webOverlaySprite!.render(
        canvas,
        position: Vector2(-22, -size.y * 0.65),
        size: Vector2(44, 34),
      );
    }

    canvas.restore();

    // Overhead Boss Health Bar
    if (bossState != BossState.escaped) {
      const barW = 52.0;
      const barH = 5.0;
      final barY = -size.y - 6.0;
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
        final fillPaint = hasTriggeredEnrage ? _hpEnrage : _hpRed;
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
