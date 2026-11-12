import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

enum DropType { heal, webFluid, shield, compoundV }

/// Collectible supply drop left behind when syndicate enemies are neutralized.
class PickupDrop extends PositionComponent with CollisionCallbacks, HasGameReference {
  final DropType type;
  final double groundLevel;
  double _lifeTimer = 16.0;
  double _bobTimer = 0.0;
  double _verticalVelocity;
  bool _isGrounded;
  bool _isCollected = false;

  Sprite? _sprite;

  PickupDrop({
    required Vector2 position,
    required this.type,
    this.groundLevel = 496.0,
    bool startGrounded = true,
  })  : _isGrounded = startGrounded,
        _verticalVelocity = startGrounded ? 0.0 : -120.0,
        super(
          position: position,
          size: type == DropType.compoundV ? Vector2(22, 22) : Vector2(20, 26),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    final assetPath = switch (type) {
      DropType.heal => 'drop/heal.png',
      DropType.webFluid => 'drop/web-fluid.png',
      DropType.shield => 'drop/shield.png',
      DropType.compoundV => 'drop/compound-v.png',
    };

    try {
      _sprite = await Sprite.load(assetPath);
    } catch (_) {
      _sprite = null;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isCollected) return;

    _lifeTimer -= dt;
    if (_lifeTimer <= 0) {
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
      return;
    }

    _bobTimer += dt;

    if (!_isGrounded) {
      _verticalVelocity += GameConfig.gravity.y * dt * 0.7;
      position.y += _verticalVelocity * dt;

      if (position.y >= groundLevel) {
        position.y = groundLevel;
        _verticalVelocity = 0.0;
        _isGrounded = true;
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (_isCollected) return;

    // Settle onto warehouse platforms
    if (other is WarehousePlatform && !_isGrounded && _verticalVelocity >= 0) {
      final platTop = other.position.y;
      if (position.y >= platTop - 4.0 && position.y <= platTop + 18.0) {
        position.y = platTop;
        _verticalVelocity = 0.0;
        _isGrounded = true;
      }
    }

    // Collected by player
    if (other is Spidey) {
      _isCollected = true;
      _applyToPlayer(other);
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
    }
  }

  void _applyToPlayer(Spidey player) {
    switch (type) {
      case DropType.heal:
        player.health = math.min(player.health + 1, Spidey.maxHealth);
        AudioManager.instance.playPunch();
        parent?.add(
          DamageNumber(
            amount: 1,
            position: position - Vector2(0, size.y + 12.0),
            color: const Color(0xFF10B981),
          ),
        );
        break;
      case DropType.webFluid:
        player.webFluid = math.min(player.webFluid + 5.0, Spidey.maxWebFluid.toDouble());
        AudioManager.instance.playWebShoot();
        parent?.add(
          DamageNumber(
            amount: 5,
            position: position - Vector2(0, size.y + 12.0),
            color: const Color(0xFF38BDF8),
          ),
        );
        break;
      case DropType.shield:
        player.shieldTimer = 1.0; // Invulnerable for 1 second!
        AudioManager.instance.playButtonClick();
        parent?.add(
          DamageNumber(
            amount: 0,
            position: position - Vector2(0, size.y + 12.0),
            color: const Color(0xFFFACC15),
          ),
        );
        break;
      case DropType.compoundV:
        player.skill1Cooldown = 0.0;
        player.webFluid = Spidey.maxWebFluid.toDouble();
        AudioManager.instance.playSwing();
        parent?.add(
          DamageNumber(
            amount: 10,
            position: position - Vector2(0, size.y + 12.0),
            color: const Color(0xFFA855F7),
          ),
        );
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Smooth floating bobbing motion (floating higher above ground/platform)
    final bobY = (math.sin(_bobTimer * 4.0) * 3.5) - 12.0;

    // Render drop sprite cleanly
    if (_sprite != null) {
      _sprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y + bobY),
        size: size,
      );
    } else {
      // Fallback rect without circles
      final fbColor = switch (type) {
        DropType.heal => const Color(0xFF10B981),
        DropType.webFluid => const Color(0xFF38BDF8),
        DropType.shield => const Color(0xFFFACC15),
        DropType.compoundV => const Color(0xFFA855F7),
      };
      final fbPaint = Paint()..color = fbColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-size.x * 0.5, -size.y + bobY, size.x, size.y),
          const Radius.circular(4),
        ),
        fbPaint,
      );
    }
  }
}
