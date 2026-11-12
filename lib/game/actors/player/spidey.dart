import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/enemies/thug.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/enemies/minion_with_gun.dart';
import 'package:spideyhood/game/components/building.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/components/ground.dart';
import 'package:spideyhood/game/components/web_ammo.dart';
import 'package:spideyhood/game/components/web_mark.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

enum SpideyState { idle, running, jumping, swinging, attacking, kicking, skill1 }

/// Bounding box and ground anchor metadata for idle animation frames
class _IdleFrameData {
  final double imgW;
  final double imgH;
  final double centerX;
  final double feetY;
  final double scaleRefH;

  const _IdleFrameData({
    required this.imgW,
    required this.imgH,
    required this.centerX,
    required this.feetY,
    required this.scaleRefH,
  });
}

class Spidey extends PositionComponent with CollisionCallbacks, HasGameReference {
  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  bool isFacingRight = true;
  bool ignorePlatformLanding = false;
  SpideyState state = SpideyState.idle;

  // Custom player sprite assets
  final List<Sprite> _idleSprites = [];
  int _currentIdleIndex = 0;
  double _idleTimer = 0.0;

  // Jump animation sprites: swing/2.png
  final List<Sprite> _jumpSprites = [];
  int _currentJumpIndex = 0;
  double _jumpTimer = 0.0;

  // Active web-swinging sprite: swing/1.png
  Sprite? _webSwingSprite;

  // Punch animation frames: attack/punch_1/1.png to 4.png (18 damage)
  final List<Sprite> _punchSprites = [];
  // Kick animation frames: attack/punch_2/5.png to 8.png (32 damage)
  final List<Sprite> _kickSprites = [];
  int _currentAttackIndex = 0;
  static const double punchDuration = 0.36; // Snappy 4-frame punch (~0.09s per frame)
  static const double kickDuration = 0.44;  // Impactful 4-frame roundhouse kick (~0.11s per frame)
  double attackTimer = 0.0;
  bool _hasHitInCurrentAttack = false;

  // Walking animation sprites: walking/2.png, walking/3.png, walking/4.png
  final List<Sprite> _walkSprites = [];
  int _currentWalkIndex = 0;
  double _walkTimer = 0.0;

  static const List<_IdleFrameData> _walkFrameData = [
    _IdleFrameData(imgW: 192, imgH: 256, centerX: 96.0, feetY: 255.0, scaleRefH: 228.0),
    _IdleFrameData(imgW: 179, imgH: 239, centerX: 89.5, feetY: 238.0, scaleRefH: 237.0),
  ];

  // Skill 1 animation sprites: attack/skill_1/1.png
  final List<Sprite> _skill1Sprites = [];
  int _currentSkill1Index = 0;
  double _skill1Timer = 0.0;
  bool _hasFiredSkill1Ammo = false;
  static const double skill1Duration = 0.38;

  static const List<_IdleFrameData> _skill1FrameData = [
    _IdleFrameData(imgW: 210, imgH: 280, centerX: 104.5, feetY: 277.0, scaleRefH: 230.0),
  ];

  // Web strand sprites: swing_one.png & swing_two.png (randomly chosen on shoot)
  final List<Sprite> _webSprites = [];
  int _selectedWebIndex = 0;
  final math.Random _random = math.Random();

  // Idle frame durations: frames 1..8 (0.18s per frame for smooth natural breathing)
  static const List<double> idleFrameDurations = [
    0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18,
  ];

  // Punch frame metadata (frames 1..2 in attack/punch/)
  static const List<_IdleFrameData> _punchFrameData = [
    _IdleFrameData(imgW: 173, imgH: 231, centerX: 83.0, feetY: 228.0, scaleRefH: 229.0),
    _IdleFrameData(imgW: 210, imgH: 280, centerX: 104.5, feetY: 277.0, scaleRefH: 230.0),
  ];

  // Kick frame metadata (frames 1..2 in attack/kick/)
  static const List<_IdleFrameData> _kickFrameData = [
    _IdleFrameData(imgW: 189, imgH: 252, centerX: 100.5, feetY: 251.0, scaleRefH: 251.0),
    _IdleFrameData(imgW: 222, imgH: 296, centerX: 112.5, feetY: 295.0, scaleRefH: 256.0),
  ];

  // Feet and center alignment data to ensure perfectly grounded, smooth frame transitions
  static const List<_IdleFrameData> _idleFrameData = [
    _IdleFrameData(imgW: 148, imgH: 263, centerX: 71.5, feetY: 262.0, scaleRefH: 255.0),
    _IdleFrameData(imgW: 148, imgH: 263, centerX: 74.0, feetY: 262.0, scaleRefH: 256.0),
    _IdleFrameData(imgW: 147, imgH: 261, centerX: 72.5, feetY: 260.0, scaleRefH: 253.0),
    _IdleFrameData(imgW: 141, imgH: 251, centerX: 68.0, feetY: 250.0, scaleRefH: 251.0),
    _IdleFrameData(imgW: 142, imgH: 252, centerX: 69.5, feetY: 251.0, scaleRefH: 251.0),
    _IdleFrameData(imgW: 142, imgH: 253, centerX: 63.5, feetY: 251.0, scaleRefH: 252.0),
    _IdleFrameData(imgW: 140, imgH: 248, centerX: 71.5, feetY: 247.0, scaleRefH: 248.0),
    _IdleFrameData(imgW: 141, imgH: 251, centerX: 67.5, feetY: 250.0, scaleRefH: 251.0),
  ];

  // Web-swinging state
  Vector2? webAnchor;
  double webLength = 0.0;

  // Cached paint objects to guarantee 0 per-frame GC allocations
  final Paint _shadowPaint = Paint();
  static final Paint _fallbackWebPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static final Paint _fallbackRedPaint = Paint()..color = const Color(0xFFD62828);
  static final Paint _fallbackBluePaint = Paint()..color = const Color(0xFF003049);
  static final Paint _fallbackEyePaint = Paint()..color = Colors.white;
  static final Paint _fallbackBlackOutline = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _fallbackLogoPaint = Paint()..color = Colors.black;
  double swingAngle = 0.0;
  double angularVelocity = 0.0;
  double _moveInput = 0.0;
  int _jumpCount = 0;
  WarehousePlatform? currentPlatform;
  double _platformDropTimer = 0.0;

  // Combat state (5 Hearts system, Web Fluid limit & Skill Cooldown)
  static const int maxHealth = 5;
  int health = maxHealth;
  bool get isDefeated => health <= 0;
  static const int maxWebFluid = 10;
  double webFluid = 10.0;
  static const double webFluidRegenRate = 0.75;
  static const double skill1CooldownMax = 3.0;
  double skill1Cooldown = 0.0;
  double shieldTimer = 0.0;
  double _invulnerableTimer = 0.0;
  bool? isGodMode;
  bool get activeGodMode => isGodMode ?? GameConfig.godMode;

  // World bounds for current level/stage
  final double groundLevel;
  final double worldWidth;

  Spidey({
    required Vector2 position,
    Vector2? size,
    this.groundLevel = GameConfig.groundY,
    this.worldWidth = GameConfig.bgWidth,
    this.isGodMode,
  }) : super(
          position: position,
          size: size ?? GameConfig.playerSize,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    // Load all idle animation frames (1..8 in player/idle/)
    _idleSprites.clear();
    for (int i = 1; i <= 8; i++) {
      try {
        final s = await Sprite.load('player/idle/$i.png');
        _idleSprites.add(s);
      } catch (_) {}
    }

    // Jump animation frame: swing/2.png
    _jumpSprites.clear();
    try {
      final s = await Sprite.load('player/swing/2.png');
      _jumpSprites.add(s);
    } catch (_) {
      for (int i = 1; i <= 5; i++) {
        try {
          final s = await Sprite.load('player/swing/$i.png');
          _jumpSprites.add(s);
        } catch (_) {}
      }
    }

    // Active web-swinging sprite: swing/1.png
    try {
      _webSwingSprite = await Sprite.load('player/swing/1.png');
    } catch (_) {
      try {
        _webSwingSprite = await Sprite.load('player/swing/6.png');
      } catch (_) {
        _webSwingSprite = null;
      }
    }

    // Load punch animation frames (1..2 in attack/punch/)
    _punchSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('player/attack/punch/$i.png');
        _punchSprites.add(s);
      } catch (_) {
        try {
          final s = await Sprite.load('player/attack/punch_1/$i.png');
          _punchSprites.add(s);
        } catch (_) {}
      }
    }

    // Load kick animation frames (1..2 in attack/kick/)
    _kickSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('player/attack/kick/$i.png');
        _kickSprites.add(s);
      } catch (_) {
        try {
          final s = await Sprite.load('player/attack/punch_2/${i + 4}.png');
          _kickSprites.add(s);
        } catch (_) {}
      }
    }

    // Running animation frames: running/1.png to running/2.png
    _walkSprites.clear();
    for (int i = 1; i <= 2; i++) {
      try {
        final s = await Sprite.load('player/running/$i.png');
        _walkSprites.add(s);
      } catch (_) {
        try {
          final s = await Sprite.load('player/walking/$i.png');
          _walkSprites.add(s);
        } catch (_) {}
      }
    }

    // Skill 1 animation frame: attack/skill_1/1.png
    _skill1Sprites.clear();
    try {
      final s = await Sprite.load('player/attack/skill_1/1.png');
      _skill1Sprites.add(s);
    } catch (_) {
      try {
        final s = await Sprite.load('player/skill_1/1.png');
        _skill1Sprites.add(s);
      } catch (_) {}
    }

    // Web line sprites: 1.png, 2.png, 3.png from assets/images/player/web_swing/
    _webSprites.clear();
    for (int i = 1; i <= 3; i++) {
      try {
        final s = await Sprite.load('player/web_swing/$i.png');
        _webSprites.add(s);
      } catch (_) {}
    }
    if (_webSprites.isEmpty) {
      try {
        final s1 = await Sprite.load('player/web_swing/swing_one.png');
        _webSprites.add(s1);
      } catch (_) {}
      try {
        final s2 = await Sprite.load('player/web_swing/swing_two.png');
        _webSprites.add(s2);
      } catch (_) {}
    }
  }

  /// Run horizontally (-1.0 for left, 1.0 for right, 0.0 for stop)
  void move(double direction) {
    _moveInput = direction;
    if (direction != 0) {
      isFacingRight = direction > 0;
    }
  }

  /// Jump, double-jump, or release swinging web
  void jump() {
    currentPlatform = null;
    if (state == SpideyState.swinging) {
      releaseWeb(withBoost: true);
      _jumpCount = 1;
      return;
    }

    if (isGrounded) {
      // First jump from ground
      velocity.y = GameConfig.jumpVelocity;
      isGrounded = false;
      state = SpideyState.jumping;
      _jumpTimer = 0.0;
      _currentJumpIndex = 0;
      _jumpCount = 1;
      AudioManager.instance.playJump();
    } else if (_jumpCount == 1) {
      // Mid-air double jump leap
      velocity.y = GameConfig.jumpVelocity * 0.88;
      state = SpideyState.jumping;
      _jumpTimer = 0.0;
      _currentJumpIndex = 0;
      _jumpCount = 2;
      AudioManager.instance.playJump();
    }
  }

  /// Drop down from an elevated platform
  void dropDownPlatform() {
    if (state == SpideyState.swinging) {
      releaseWeb();
    }
    if (currentPlatform != null || (isGrounded && position.y < groundLevel - 15.0)) {
      currentPlatform = null;
      isGrounded = false;
      ignorePlatformLanding = true;
      _platformDropTimer = 0.35; // allow falling through the current platform
      position.y += 8.0;
      velocity.y = 120.0;
      state = SpideyState.jumping;
      _jumpTimer = 0.0;
      _currentJumpIndex = 0;
      _jumpCount = 1;
    }
  }

  /// Fire a web at any target anchor point
  void shootWeb(Vector2 targetAnchor) {
    if (!activeGodMode && webFluid < 1.0) {
      AudioManager.instance.playButtonClick();
      return;
    }
    if (!activeGodMode) {
      webFluid = math.max(0.0, webFluid - 1.0);
    } else {
      webFluid = maxWebFluid.toDouble();
    }
    currentPlatform = null;
    // If target is too low, raise it slightly so Spidey can swing
    final effectiveAnchor = targetAnchor.y >= position.y - 40
        ? Vector2(targetAnchor.x, position.y - 120)
        : targetAnchor;

    final diff = effectiveAnchor - (position - Vector2(0, size.y / 2));
    final dist = diff.length;

    webAnchor = effectiveAnchor;
    webLength = math.min(dist, GameConfig.maxWebDistance);

    // Calculate initial swing angle (0 = directly below anchor)
    final offset = (position - Vector2(0, size.y / 2)) - effectiveAnchor;
    swingAngle = math.atan2(offset.x, offset.y);
    // Bound initial swing angle within realistic pendulum limits
    swingAngle = swingAngle.clamp(-1.25, 1.25);

    // Convert full velocity vector (horizontal + vertical fall momentum) into tangential swing velocity:
    // v_theta = v_x * cos(theta) - v_y * sin(theta)
    final tangentialVel = velocity.x * math.cos(swingAngle) - velocity.y * math.sin(swingAngle);
    angularVelocity = tangentialVel / math.max(webLength, 1.0);

    // If standing/still or near vertical, start at rest hanging on web
    if (velocity.length < 35 && swingAngle.abs() < 0.15) {
      angularVelocity = 0.0;
      swingAngle = 0.0;
    } else if (angularVelocity.abs() < 1.2) {
      angularVelocity = isFacingRight ? 2.2 : -2.2;
    }
    angularVelocity = angularVelocity.clamp(-4.2, 4.2);

    state = SpideyState.swinging;
    isGrounded = false;
    AudioManager.instance.playWebShoot();

    // Pick randomly between web swing sprites 1, 2, and 3
    if (_webSprites.isNotEmpty) {
      _selectedWebIndex = _random.nextInt(_webSprites.length);
    }
  }

  /// Release web swing and preserve momentum
  void releaseWeb({bool withBoost = false}) {
    if (webAnchor == null) return;
    AudioManager.instance.playSwing();

    // Leave a web mark (using web_swing/4.png) at the anchor tip that dissolves over 7 seconds
    if (parent != null) {
      parent!.add(WebMark(position: webAnchor!.clone()));
    }

    final tangentialSpeed = angularVelocity * webLength;
    final boost = withBoost ? GameConfig.swingBoostImpulse : 0.0;
    final speedWithBoost = tangentialSpeed + (angularVelocity > 0 ? boost : -boost);

    // Convert angular velocity back to Cartesian velocity vector
    velocity.x = math.cos(swingAngle) * speedWithBoost;
    velocity.y = -math.sin(swingAngle) * speedWithBoost - (withBoost ? 180.0 : 0.0);

    // Clamp horizontal launch speed to solid superhero bounds
    velocity.x = velocity.x.clamp(-750.0, 750.0);
    velocity.y = velocity.y.clamp(-650.0, 450.0);

    webAnchor = null;
    state = SpideyState.jumping;
    _jumpTimer = 0.0;
    _currentJumpIndex = 0;
  }

  /// Perform combat punch (Punch 1, 18 damage)
  void punch() {
    if (state == SpideyState.attacking || state == SpideyState.kicking || state == SpideyState.skill1) return;

    state = SpideyState.attacking;
    attackTimer = punchDuration;
    _currentAttackIndex = 0;
    _hasHitInCurrentAttack = false;
    AudioManager.instance.playPunch();

    _applyCombatDamage(damage: 18, knockback: 280.0, isKick: false);
  }

  /// Perform combat kick (Punch 2 / Kick, 32 damage, stronger knockback)
  void kick() {
    if (state == SpideyState.attacking || state == SpideyState.kicking || state == SpideyState.skill1) return;
    if (state == SpideyState.swinging) {
      releaseWeb();
    }

    state = SpideyState.kicking;
    attackTimer = kickDuration;
    _currentAttackIndex = 0;
    _hasHitInCurrentAttack = false;
    AudioManager.instance.playPunch();

    _applyCombatDamage(damage: 32, knockback: 400.0, isKick: true);
  }

  void _applyCombatDamage({
    required int damage,
    required double knockback,
    required bool isKick,
  }) {
    if (parent == null) return;
    final forwardReach = isKick ? 85.0 : 70.0;
    final backwardReach = 26.0; // Generous backward/overlap coverage for point-blank hits
    final totalW = forwardReach + backwardReach;
    final dir = isFacingRight ? 1.0 : -1.0;
    final centerOffset = isFacingRight ? (forwardReach - backwardReach) * 0.5 : -(forwardReach - backwardReach) * 0.5;

    final attackBox = Rect.fromCenter(
      center: Offset(position.x + centerOffset, position.y - size.y * 0.5),
      width: totalW,
      height: size.y * 1.6, // Generous vertical tolerance for platforms and jump attacks
    );

    // Single target focus: do damage one at a time to the closest enemy
    PositionComponent? closestEnemy;
    double closestDist = double.infinity;

    for (final comp in parent!.children.whereType<Thug>().toList()) {
      if (!comp.isDefeated && attackBox.overlaps(comp.toRect())) {
        final d = (comp.position.x - position.x).abs();
        if (d < closestDist) {
          closestDist = d;
          closestEnemy = comp;
        }
      }
    }

    for (final comp in parent!.children.whereType<ViperGuard>().toList()) {
      if (!comp.isDefeated && attackBox.overlaps(comp.toRect())) {
        final d = (comp.position.x - position.x).abs();
        if (d < closestDist) {
          closestDist = d;
          closestEnemy = comp;
        }
      }
    }

    for (final comp in parent!.children.whereType<ViperBoss>().toList()) {
      if (comp.bossState != BossState.escaped && attackBox.overlaps(comp.toRect())) {
        final d = (comp.position.x - position.x).abs();
        if (d < closestDist) {
          closestDist = d;
          closestEnemy = comp;
        }
      }
    }

    for (final comp in parent!.children.whereType<MinionWithGun>().toList()) {
      if (!comp.isDefeated && attackBox.overlaps(comp.toRect())) {
        final d = (comp.position.x - position.x).abs();
        if (d < closestDist) {
          closestDist = d;
          closestEnemy = comp;
        }
      }
    }

    if (closestEnemy != null) {
      if (closestEnemy is Thug) {
        closestEnemy.takeDamage(damage, dir * (knockback / 320.0));
      } else if (closestEnemy is ViperGuard) {
        closestEnemy.takeDamage(damage, dir * (knockback / 320.0));
      } else if (closestEnemy is ViperBoss) {
        closestEnemy.takeDamage(damage, dir * (knockback / 320.0));
      } else if (closestEnemy is MinionWithGun) {
        closestEnemy.takeDamage(damage, dir * (knockback / 320.0));
      }
      _hasHitInCurrentAttack = true;
    }
  }

  /// Take damage from enemies or boss attacks (5 Hearts system with invulnerability & shield)
  void takeDamage(int amount) {
    if (health <= 0) return;
    if (activeGodMode) {
      // In Godmode, Spidey is completely invincible (infinite health)
      health = maxHealth;
      AudioManager.instance.playButtonClick();
      Future.microtask(() {
        if (parent != null) {
          parent?.add(
            DamageNumber(
              amount: 0,
              position: position - Vector2(0, size.y + 12.0),
              color: const Color(0xFFFACC15),
            ),
          );
        }
      });
      return;
    }
    if (shieldTimer > 0) {
      AudioManager.instance.playButtonClick();
      Future.microtask(() {
        if (parent != null) {
          parent?.add(
            DamageNumber(
              amount: 0,
              position: position - Vector2(0, size.y + 12.0),
              color: const Color(0xFFFACC15),
            ),
          );
        }
      });
      return;
    }
    if (_invulnerableTimer > 0) return;

    _invulnerableTimer = 0.8;
    final heartDamage = amount >= 30 ? 2 : 1;
    health = math.max(0, health - heartDamage);
    AudioManager.instance.playPunch();

    // Spawn damage indicator above Spider-Man safely
    Future.microtask(() {
      if (parent != null) {
        parent?.add(
          DamageNumber(
            amount: heartDamage,
            position: position - Vector2(0, size.y + 12.0),
            color: const Color(0xFFEF4444),
          ),
        );
      }
    });
  }

  /// Perform Skill 1 (Web Shot projectile blast, 35 damage, 3.0s cooldown)
  void useSkill1() {
    if (!activeGodMode && skill1Cooldown > 0) return;
    if (state == SpideyState.attacking || state == SpideyState.kicking || state == SpideyState.skill1) return;
    if (state == SpideyState.swinging) {
      releaseWeb();
    }

    skill1Cooldown = activeGodMode ? 0.0 : skill1CooldownMax;
    state = SpideyState.skill1;
    _skill1Timer = skill1Duration;
    _currentSkill1Index = 0;
    _hasFiredSkill1Ammo = false;
    velocity.x = 0;
  }

  void _fireSkill1Ammo() {
    if (parent == null) return;
    final dir = isFacingRight ? 1.0 : -1.0;
    final handX = position.x + dir * (size.x * 0.82);
    final handY = position.y - (size.y * 0.735);
    const ammoW = 78.0;
    final spawnPos = Vector2(handX + dir * (ammoW * 0.5), handY);
    final ammo = WebAmmo(
      position: spawnPos,
      direction: dir,
    );
    parent!.add(ammo);
    AudioManager.instance.playWebShoot();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Timers: Invulnerability, Shield, Skill Cooldown & Fast Web Fluid Regeneration
    if (_platformDropTimer > 0) {
      _platformDropTimer = math.max(0.0, _platformDropTimer - dt);
      if (_platformDropTimer <= 0) {
        ignorePlatformLanding = false;
      }
    }

    if (activeGodMode) {
      health = maxHealth;
      webFluid = maxWebFluid.toDouble();
      skill1Cooldown = 0.0;
    } else {
      if (_invulnerableTimer > 0) _invulnerableTimer = math.max(0.0, _invulnerableTimer - dt);
      if (shieldTimer > 0) shieldTimer = math.max(0.0, shieldTimer - dt);
      if (skill1Cooldown > 0) skill1Cooldown = math.max(0.0, skill1Cooldown - dt);
      webFluid = math.min(maxWebFluid.toDouble(), webFluid + (webFluidRegenRate * dt));
    }

    // Update animated idle sequence (frames 1..8 slower and relaxed, 9..11 fast animation)
    if (state == SpideyState.idle && isGrounded) {
      _idleTimer += dt;
      if (_idleSprites.isNotEmpty) {
        final currentDuration = _currentIdleIndex < idleFrameDurations.length
            ? idleFrameDurations[_currentIdleIndex]
            : 0.38;
        if (_idleTimer >= currentDuration) {
          _idleTimer -= currentDuration;
          _currentIdleIndex = (_currentIdleIndex + 1) % _idleSprites.length;
        }
      }
    } else {
      _idleTimer = 0.0;
      _currentIdleIndex = 0;
    }

    // Animate acrobatic jump frames (1..5) while airborne
    if (!isGrounded && state == SpideyState.jumping) {
      _jumpTimer += dt;
      if (_jumpSprites.isNotEmpty) {
        if (_jumpTimer < 0.10) {
          _currentJumpIndex = 0;
        } else if (_jumpTimer < 0.20) {
          _currentJumpIndex = 1;
        } else if (_jumpTimer < 0.30) {
          _currentJumpIndex = 2;
        } else if (_jumpTimer < 0.40) {
          _currentJumpIndex = 3;
        } else {
          _currentJumpIndex = 4;
        }
        _currentJumpIndex = _currentJumpIndex.clamp(0, _jumpSprites.length - 1);
      }
    } else {
      _jumpTimer = 0.0;
      _currentJumpIndex = 0;
    }

    // Update animated walking sequence when moving along the ground
    if (state == SpideyState.running && isGrounded) {
      _walkTimer += dt * (velocity.x.abs() / GameConfig.walkSpeed).clamp(0.5, 1.5);
      const walkStepDuration = 0.14;
      if (_walkSprites.isNotEmpty) {
        final cycleStep = (_walkTimer / walkStepDuration).floor() % _walkSprites.length;
        _currentWalkIndex = cycleStep.clamp(0, _walkSprites.length - 1);
      }
    } else {
      _walkTimer = 0.0;
      _currentWalkIndex = 0;
    }

    // Punch attack sequence (Punch, frames 1..2 in attack/punch/)
    if (state == SpideyState.attacking) {
      attackTimer -= dt;
      final elapsed = punchDuration - attackTimer;
      if (_punchSprites.isNotEmpty) {
        final frameDuration = punchDuration / _punchSprites.length;
        _currentAttackIndex = (elapsed / frameDuration).floor().clamp(0, _punchSprites.length - 1);
      }
      if (!_hasHitInCurrentAttack) {
        _applyCombatDamage(damage: 18, knockback: 280.0, isKick: false);
      }
      if (attackTimer <= 0) {
        state = isGrounded ? (velocity.x != 0 ? SpideyState.running : SpideyState.idle) : SpideyState.jumping;
      }
    }

    // Kick attack sequence (Kick, frames 1..2 in attack/kick/)
    if (state == SpideyState.kicking) {
      attackTimer -= dt;
      final elapsed = kickDuration - attackTimer;
      if (_kickSprites.isNotEmpty) {
        final frameDuration = kickDuration / _kickSprites.length;
        _currentAttackIndex = (elapsed / frameDuration).floor().clamp(0, _kickSprites.length - 1);
      }
      if (!_hasHitInCurrentAttack) {
        _applyCombatDamage(damage: 32, knockback: 400.0, isKick: true);
      }
      if (attackTimer <= 0) {
        state = isGrounded ? (velocity.x != 0 ? SpideyState.running : SpideyState.idle) : SpideyState.jumping;
      }
    }

    // Skill 1: Web Shot animation and ammo release
    if (state == SpideyState.skill1) {
      _skill1Timer -= dt;
      final elapsed = skill1Duration - _skill1Timer;
      if (_skill1Sprites.isNotEmpty) {
        final frameDuration = skill1Duration / _skill1Sprites.length;
        _currentSkill1Index = (elapsed / frameDuration).floor().clamp(0, _skill1Sprites.length - 1);
      }
      if (!_hasFiredSkill1Ammo && elapsed >= 0.10) {
        _hasFiredSkill1Ammo = true;
        _fireSkill1Ammo();
      }
      if (_skill1Timer <= 0) {
        if (!_hasFiredSkill1Ammo) {
          _hasFiredSkill1Ammo = true;
          _fireSkill1Ammo();
        }
        state = isGrounded ? (velocity.x.abs() > 8.0 ? SpideyState.running : SpideyState.idle) : SpideyState.jumping;
      }
    }

    if (state == SpideyState.swinging && webAnchor != null) {
      _updateWebPhysics(dt);
    } else {
      _updateNormalPhysics(dt);
    }
  }

  void _updateWebPhysics(double dt) {
    final anchor = webAnchor!;
    final isMoving = _moveInput != 0;

    // When stopped while hanging and player is not moving left or right, stay completely still
    if (!isMoving && angularVelocity.abs() < 0.28 && swingAngle.abs() < 0.12) {
      angularVelocity = 0.0;
      swingAngle = 0.0;
    } else {
      // User pumping / steering torque via A & D or arrow keys
      if (isMoving) {
        angularVelocity += _moveInput * 3.8 * dt;
        isFacingRight = _moveInput > 0;
      }

      // Pendulum equation: d^2(theta)/dt^2 = -(g / L) * sin(theta)
      final gravityAccel = -(GameConfig.swingGravity / webLength) * math.sin(swingAngle);
      angularVelocity += gravityAccel * dt;

      // Natural damping when user is not steering so swing smoothly settles to a stop
      final damping = isMoving ? GameConfig.swingDamping : 0.988;
      angularVelocity *= damping;

      // Prevent uncontrolled spinning: clamp max angular velocity
      angularVelocity = angularVelocity.clamp(-4.2, 4.2);

      swingAngle += angularVelocity * dt;

      // Realistic pendulum limits: ~75 degrees from vertical
      const maxSwingAngle = 1.30;
      if (swingAngle > maxSwingAngle) {
        swingAngle = maxSwingAngle;
        if (angularVelocity > 0) angularVelocity = 0;
      } else if (swingAngle < -maxSwingAngle) {
        swingAngle = -maxSwingAngle;
        if (angularVelocity < 0) angularVelocity = 0;
      }

      // Face the direction of the swing
      if (angularVelocity.abs() > 0.15) {
        isFacingRight = angularVelocity > 0;
      }
    }

    // Update Spidey position along pendulum arc
    final centerPos = anchor + Vector2(
      math.sin(swingAngle) * webLength,
      math.cos(swingAngle) * webLength,
    );
    position = centerPos + Vector2(0, size.y / 2);

    // Never swing below the ground level
    if (position.y >= groundLevel) {
      position.y = groundLevel;
      releaseWeb();
    }

    // Clamp horizontally to image boundaries [0, worldWidth]
    final halfW = size.x / 2;
    position.x = position.x.clamp(halfW, worldWidth - halfW);
  }

  void _updateNormalPhysics(double dt) {
    if (!isGrounded) {
      velocity.y += GameConfig.gravity.y * dt;

      // In-air steering control: allow responsive left/right guidance while preserving high leap momentum
      if (_moveInput != 0) {
        final targetVx = _moveInput * GameConfig.walkSpeed;
        if (_moveInput > 0) {
          if (velocity.x < targetVx) {
            velocity.x = math.min(targetVx, velocity.x + 600.0 * dt);
          }
          isFacingRight = true;
        } else {
          if (velocity.x > targetVx) {
            velocity.x = math.max(targetVx, velocity.x - 600.0 * dt);
          }
          isFacingRight = false;
        }
      }
    } else {
      // Ground walking with smooth, grounded acceleration & deceleration (less twitchy / sensitive)
      final targetVx = _moveInput * GameConfig.walkSpeed;
      if (_moveInput != 0) {
        isFacingRight = _moveInput > 0;
        if (velocity.x < targetVx) {
          velocity.x = math.min(targetVx, velocity.x + 750.0 * dt);
        } else if (velocity.x > targetVx) {
          velocity.x = math.max(targetVx, velocity.x - 750.0 * dt);
        }
      } else {
        // Quick, clean deceleration to standstill
        if (velocity.x > 0) {
          velocity.x = math.max(0.0, velocity.x - 1100.0 * dt);
        } else if (velocity.x < 0) {
          velocity.x = math.min(0.0, velocity.x + 1100.0 * dt);
        }
      }

      if (state != SpideyState.attacking && state != SpideyState.kicking && state != SpideyState.skill1) {
        state = velocity.x.abs() > 8.0 ? SpideyState.running : SpideyState.idle;
      }
    }

    // Platform grounding check (firm footing on catwalk planks)
    if (currentPlatform != null) {
      final platLeft = currentPlatform!.position.x;
      final platRight = platLeft + currentPlatform!.size.x;
      if (position.x >= platLeft - 8.0 &&
          position.x <= platRight + 8.0 &&
          velocity.y >= 0 &&
          state != SpideyState.swinging) {
        position.y = currentPlatform!.position.y;
        velocity.y = 0;
        isGrounded = true;
        _jumpCount = 0;
        _jumpTimer = 0.0;
        _currentJumpIndex = 0;
        if (state != SpideyState.attacking &&
            state != SpideyState.kicking &&
            state != SpideyState.skill1) {
          state = velocity.x.abs() > 8.0 ? SpideyState.running : SpideyState.idle;
        }
      } else {
        currentPlatform = null;
        isGrounded = false;
      }
    }

    position += velocity * dt;

    // Hard boundary: Spidey will never fall below the ground surface
    if (position.y >= groundLevel) {
      position.y = groundLevel;
      velocity.y = 0;
      isGrounded = true;
      currentPlatform = null;
      _jumpCount = 0;
      _jumpTimer = 0.0;
      _currentJumpIndex = 0;
      if (state != SpideyState.attacking && state != SpideyState.kicking && state != SpideyState.skill1) {
        state = velocity.x.abs() > 8.0 ? SpideyState.running : SpideyState.idle;
      }
    } else if (currentPlatform == null) {
      if (velocity.y > 50 &&
          state != SpideyState.swinging &&
          state != SpideyState.skill1 &&
          state != SpideyState.attacking &&
          state != SpideyState.kicking) {
        state = SpideyState.jumping;
      }
      isGrounded = false;
    }

    // Clamp horizontally to image boundaries [0, worldWidth]
    final halfW = size.x / 2;
    position.x = position.x.clamp(halfW, worldWidth - halfW);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // During special cutscenes, do not prematurely land on platforms
    if (ignorePlatformLanding && other is WarehousePlatform) {
      return;
    }

    if (other is Building || other is Ground || other is WarehousePlatform) {
      final surfaceTop = other.position.y;
      final playerBottom = position.y;

      // Landing on top of surface
      if (velocity.y >= 0 && (playerBottom - surfaceTop).abs() < 18) {
        position.y = surfaceTop;
        velocity.y = 0;
        isGrounded = true;
        if (other is WarehousePlatform) {
          currentPlatform = other;
        }
        _jumpCount = 0;
        _jumpTimer = 0.0;
        _currentJumpIndex = 0;
        if (state == SpideyState.swinging) {
          releaseWeb();
        }
        if (state != SpideyState.attacking &&
            state != SpideyState.kicking &&
            state != SpideyState.skill1) {
          state = velocity.x.abs() > 10 ? SpideyState.running : SpideyState.idle;
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Ground contact shadow (anchors character firmly to the ground)
    final shadowY = groundLevel - position.y;
    final shadowScale = (1.0 - (shadowY / 200.0)).clamp(0.2, 1.0);
    final shadowAlpha = (0.55 * shadowScale).clamp(0.0, 0.55);
    final shadowRect = Rect.fromCenter(
      center: Offset(0, shadowY),
      width: size.x * 0.95 * shadowScale,
      height: 5.0 * shadowScale,
    );
    _shadowPaint.color = Colors.black.withValues(alpha: shadowAlpha);
    canvas.drawOval(
      shadowRect,
      _shadowPaint,
    );

    // Draw the Web line if currently swinging
    if (webAnchor != null) {
      // Exact hand position on Spidey's outstretched arm in swing/1.png
      final handDrawW = size.y * (_webSwingSprite != null ? (_webSwingSprite!.srcSize.x / _webSwingSprite!.srcSize.y) : (179 / 239));
      final handLocalX = isFacingRight ? (handDrawW * 0.28) : (-handDrawW * 0.28);
      final handLocalY = -size.y * 0.96;
      final handOffset = Offset(handLocalX, handLocalY);
      final localAnchor = (webAnchor! - position).toOffset();

      final diff = localAnchor - handOffset;
      final dist = diff.distance;
      final angle = math.atan2(diff.dy, diff.dx);

      // Render custom web sprite from assets/images/player/web_swing/ (1.png, 2.png, or 3.png)
      if (_webSprites.isNotEmpty && dist > 5) {
        final activeIdx = _selectedWebIndex % _webSprites.length;
        final sprite = _webSprites[activeIdx];
        const webCenterY = [40.0, 23.0, 36.0];
        final origW = sprite.srcSize.x;
        final origH = sprite.srcSize.y;
        final startY = activeIdx < webCenterY.length ? webCenterY[activeIdx] : (origH * 0.5);

        canvas.save();
        canvas.translate(handOffset.dx, handOffset.dy);
        canvas.rotate(angle);

        // Keep thickness natural and comic-styled while stretching along distance
        final scaleY = (dist / origW).clamp(0.12, 0.28);

        sprite.render(
          canvas,
          position: Vector2(0, -startY * scaleY),
          size: Vector2(dist, origH * scaleY),
        );
        canvas.restore();
      } else if (dist > 5) {
        // Subtle white thread fallback only if sprite is not yet loaded
        canvas.drawLine(handOffset, localAnchor, _fallbackWebPaint);
      }
    }

    // Invulnerable Shield Bubble (golden barrier active for 1 second)
    if (shieldTimer > 0) {
      final shieldPaint = Paint()
        ..color = const Color(0xFFFACC15).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = const Color(0xFFEAB308).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final shieldRect = Rect.fromCenter(
        center: Offset(0, -size.y * 0.5),
        width: size.x * 1.5,
        height: size.y * 1.25,
      );
      canvas.drawOval(shieldRect, shieldPaint);
      canvas.drawOval(shieldRect, borderPaint);
    }

    // Flip horizontally when facing left
    if (!isFacingRight) {
      canvas.save();
      canvas.scale(-1, 1);
    }

    // Select active sprite according to state:
    // 0. When casting Skill 1 (Web Shot): skill_1 animation (1..3)
    // 1. When punching / attacking: attack animation (1..8)
    // 2. When swinging on a web: swing/1.png
    // 3. When jumping or web released in air: swing/2.png
    // 4. When idle on the ground: animated idle sequence (1..11) with smooth cross-fade
    // 5. When running / moving: walking animation (2..4..3)
    if (state == SpideyState.skill1 &&
        _skill1Sprites.isNotEmpty &&
        _currentSkill1Index < _skill1Sprites.length &&
        _currentSkill1Index < _skill1FrameData.length) {
      final data = _skill1FrameData[_currentSkill1Index];
      final sprite = _skill1Sprites[_currentSkill1Index];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else if (state == SpideyState.attacking &&
        _punchSprites.isNotEmpty &&
        _currentAttackIndex < _punchSprites.length &&
        _currentAttackIndex < _punchFrameData.length) {
      final data = _punchFrameData[_currentAttackIndex];
      final sprite = _punchSprites[_currentAttackIndex];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else if (state == SpideyState.kicking &&
        _kickSprites.isNotEmpty &&
        _currentAttackIndex < _kickSprites.length &&
        _currentAttackIndex < _kickFrameData.length) {
      final data = _kickFrameData[_currentAttackIndex];
      final sprite = _kickSprites[_currentAttackIndex];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else if (state == SpideyState.swinging && _webSwingSprite != null) {
      final aspect = _webSwingSprite!.srcSize.x / _webSwingSprite!.srcSize.y;
      final drawWidth = size.y * aspect;
      _webSwingSprite!.render(
        canvas,
        position: Vector2(-drawWidth / 2, -size.y),
        size: Vector2(drawWidth, size.y),
      );
    } else if ((!isGrounded || state == SpideyState.jumping) && _jumpSprites.isNotEmpty) {
      final jumpSprite = _jumpSprites[_currentJumpIndex % _jumpSprites.length];
      final aspect = jumpSprite.srcSize.x / jumpSprite.srcSize.y;
      final drawWidth = size.y * aspect;
      jumpSprite.render(
        canvas,
        position: Vector2(-drawWidth / 2, -size.y),
        size: Vector2(drawWidth, size.y),
      );
    } else if (state == SpideyState.idle &&
        _idleSprites.isNotEmpty &&
        _currentIdleIndex < _idleSprites.length &&
        _currentIdleIndex < _idleFrameData.length) {
      final data = _idleFrameData[_currentIdleIndex];
      final sprite = _idleSprites[_currentIdleIndex];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else if (state == SpideyState.running &&
        isGrounded &&
        _walkSprites.isNotEmpty &&
        _currentWalkIndex < _walkSprites.length &&
        _currentWalkIndex < _walkFrameData.length) {
      final data = _walkFrameData[_currentWalkIndex];
      final sprite = _walkSprites[_currentWalkIndex];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else if (_idleSprites.isNotEmpty) {
      // Running / grounded fallback pose
      final data = _idleFrameData[0];
      final sprite = _idleSprites[0];
      final scale = size.y / data.scaleRefH;
      final drawX = -data.centerX * scale;
      final drawY = -data.feetY * scale;
      final drawW = data.imgW * scale;
      final drawH = data.imgH * scale;

      sprite.render(
        canvas,
        position: Vector2(drawX, drawY),
        size: Vector2(drawW, drawH),
      );
    } else {
      _renderCartoonSpidey(canvas);
    }

    if (!isFacingRight) {
      canvas.restore();
    }
  }

  /// Stylized Cel-Shaded Cartoon Spidey procedural fallback
  void _renderCartoonSpidey(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Torso / Body (Upper red, lower blue)
    final bodyRect = Rect.fromCenter(
      center: Offset(0, -h * 0.45),
      width: w * 0.65,
      height: h * 0.45,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)), _fallbackRedPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)), _fallbackBlackOutline);

    // Blue side panels
    final leftSide = Rect.fromLTWH(-w * 0.32, -h * 0.55, w * 0.15, h * 0.3);
    final rightSide = Rect.fromLTWH(w * 0.17, -h * 0.55, w * 0.15, h * 0.3);
    canvas.drawRect(leftSide, _fallbackBluePaint);
    canvas.drawRect(rightSide, _fallbackBluePaint);

    // Spider chest logo
    canvas.drawCircle(Offset(0, -h * 0.48), 1.6, _fallbackLogoPaint);

    // Head / Mask
    final headRect = Rect.fromCenter(
      center: Offset(0, -h * 0.8),
      width: w * 0.52,
      height: h * 0.32,
    );
    canvas.drawOval(headRect, _fallbackRedPaint);
    canvas.drawOval(headRect, _fallbackBlackOutline);

    // Mask Eyes (Iconic angled white comic lenses with thick black borders)
    final leftEye = Path()
      ..moveTo(-w * 0.18, -h * 0.82)
      ..lineTo(-w * 0.04, -h * 0.78)
      ..lineTo(-w * 0.15, -h * 0.74)
      ..close();

    final rightEye = Path()
      ..moveTo(w * 0.18, -h * 0.82)
      ..lineTo(w * 0.04, -h * 0.78)
      ..lineTo(w * 0.15, -h * 0.74)
      ..close();

    canvas.drawPath(leftEye, _fallbackEyePaint);
    canvas.drawPath(leftEye, _fallbackBlackOutline);
    canvas.drawPath(rightEye, _fallbackEyePaint);
    canvas.drawPath(rightEye, _fallbackBlackOutline);

    // Legs / Boots
    final leftLeg = Rect.fromLTWH(-w * 0.28, -h * 0.23, w * 0.22, h * 0.23);
    final rightLeg = Rect.fromLTWH(w * 0.06, -h * 0.23, w * 0.22, h * 0.23);

    canvas.drawRect(leftLeg, _fallbackBluePaint);
    canvas.drawRect(rightLeg, _fallbackBluePaint);
    canvas.drawRect(leftLeg, _fallbackBlackOutline);
    canvas.drawRect(rightLeg, _fallbackBlackOutline);

    // Red boots
    final leftBoot = Rect.fromLTWH(-w * 0.28, -h * 0.10, w * 0.22, h * 0.10);
    final rightBoot = Rect.fromLTWH(w * 0.06, -h * 0.10, w * 0.22, h * 0.10);
    canvas.drawRect(leftBoot, _fallbackRedPaint);
    canvas.drawRect(rightBoot, _fallbackRedPaint);

    // Attack punch arm extended when attacking
    if (state == SpideyState.attacking) {
      final armRect = Rect.fromLTWH(w * 0.1, -h * 0.58, w * 0.45, h * 0.14);
      canvas.drawRRect(RRect.fromRectAndRadius(armRect, const Radius.circular(4)), _fallbackRedPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(armRect, const Radius.circular(4)), _fallbackBlackOutline);
    }
  }
}
