import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/building.dart';
import 'package:spideyhood/game/components/comic_fx.dart';
import 'package:spideyhood/game/components/ground.dart';
import 'package:spideyhood/game/config/game_config.dart';

/// Neighborhood thug enemy with patrol AI and combat reactions.
class Thug extends PositionComponent with CollisionCallbacks, HasGameReference {
  int health = GameConfig.thugMaxHealth;
  double patrolDirection = 1.0;
  final double patrolSpeed = 100.0;
  final double patrolRange;
  final double originX;
  final double groundLevel;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = true;
  bool isDefeated = false;
  double _hitCooldownTimer = 0.0;

  Thug({
    required Vector2 position,
    this.patrolRange = 250.0,
    this.groundLevel = GameConfig.groundY,
  })  : originX = position.x,
        super(
          position: position,
          size: Vector2(24, 42),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  /// Take damage and knockback from Spidey's attacks
  void takeDamage(int amount, double knockbackDir) {
    if (isDefeated || _hitCooldownTimer > 0) return;
    _hitCooldownTimer = 0.22;

    health -= amount;
    velocity.x = knockbackDir * 320.0;
    velocity.y = -260.0;
    isGrounded = false;

    final damageBadge = amount >= 30
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final damageText = health <= 0 ? 'K.O.!' : '-$amount HP';

    parent?.add(
      ComicFx(
        text: damageText,
        position: position - Vector2(0, size.y * 0.7),
        badgeColor: damageBadge,
        textColor: Colors.white,
        maxDuration: health <= 0 ? 1.0 : 0.65,
      ),
    );

    if (health <= 0) {
      isDefeated = true;
      Future.delayed(const Duration(milliseconds: 600), () {
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

    if (isDefeated) {
      velocity.y += GameConfig.gravity.y * dt;
      position += velocity * dt;
      return;
    }

    // Basic patrol behavior
    if ((position.x - originX).abs() > patrolRange) {
      patrolDirection = position.x > originX ? -1.0 : 1.0;
    }

    velocity.x = patrolDirection * patrolSpeed;

    if (!isGrounded) {
      velocity.y += GameConfig.gravity.y * dt;
    }

    position += velocity * dt;

    if (position.y >= groundLevel) {
      position.y = groundLevel;
      velocity.y = 0;
      isGrounded = true;
    } else {
      isGrounded = false;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Building || other is Ground) {
      final surfaceTop = other.position.y;
      final thugBottom = position.y;

      if (velocity.y >= 0 && (thugBottom - surfaceTop).abs() < 18) {
        position.y = surfaceTop;
        velocity.y = 0;
        isGrounded = true;
      }
    }

    if (other is Spidey && !isDefeated) {
      // Check if Spidey is attacking (punch: 18 dmg, kick: 32 dmg)
      if (other.state == SpideyState.attacking) {
        final dir = other.isFacingRight ? 1.0 : -1.0;
        takeDamage(18, dir);
      } else if (other.state == SpideyState.kicking) {
        final dir = other.isFacingRight ? 1.0 : -1.0;
        takeDamage(32, dir);
      }
    }
  }

  static final Paint _skinPaint = Paint()..color = const Color(0xFFF1C27D);
  static final Paint _shirtPaint = Paint()..color = const Color(0xFF495057);
  static final Paint _stripePaint = Paint()..color = Colors.white;
  static final Paint _pantsPaint = Paint()..color = const Color(0xFF212529);
  static final Paint _beaniePaint = Paint()..color = const Color(0xFFE63946);
  static final Paint _blackOutline = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _maskPaint = Paint()..color = Colors.black;
  static final Paint _hpBgPaint = Paint()..color = Colors.black87;
  static final Paint _hpFgPaint = Paint()..color = const Color(0xFF2EC4B6);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Viewport culling: only render thugs within the active camera view
    final visible = game.camera.visibleWorldRect;
    if (position.x < visible.left - 50 || position.x > visible.right + 50) {
      return;
    }

    final w = size.x;
    final h = size.y;

    // Flip horizontally when walking left
    if (patrolDirection < 0) {
      canvas.save();
      canvas.scale(-1, 1);
    }

    // Stylized cartoon bandit / thug (Cached paints)
    // Torso
    final torso = Rect.fromCenter(center: Offset(0, -h * 0.44), width: w * 0.7, height: h * 0.42);
    canvas.drawRRect(RRect.fromRectAndRadius(torso, const Radius.circular(6)), _shirtPaint);
    // Stripes
    canvas.drawRect(Rect.fromLTWH(-w * 0.35, -h * 0.55, w * 0.7, 5), _stripePaint);
    canvas.drawRect(Rect.fromLTWH(-w * 0.35, -h * 0.42, w * 0.7, 5), _stripePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(torso, const Radius.circular(6)), _blackOutline);

    // Head
    final head = Rect.fromCenter(center: Offset(0, -h * 0.78), width: w * 0.5, height: h * 0.28);
    canvas.drawOval(head, _skinPaint);
    // Bandit eye mask
    canvas.drawRect(Rect.fromLTWH(-w * 0.25, -h * 0.84, w * 0.5, 8), _maskPaint);
    // Red Beanie
    final beanie = Rect.fromLTWH(-w * 0.26, -h * 0.94, w * 0.52, 12);
    canvas.drawRRect(RRect.fromRectAndRadius(beanie, const Radius.circular(4)), _beaniePaint);
    canvas.drawOval(head, _blackOutline);

    // Legs
    final leftLeg = Rect.fromLTWH(-w * 0.3, -h * 0.22, w * 0.25, h * 0.22);
    final rightLeg = Rect.fromLTWH(w * 0.05, -h * 0.22, w * 0.25, h * 0.22);
    canvas.drawRect(leftLeg, _pantsPaint);
    canvas.drawRect(rightLeg, _pantsPaint);
    canvas.drawRect(leftLeg, _blackOutline);
    canvas.drawRect(rightLeg, _blackOutline);

    // Health bar above head
    if (!isDefeated && health < GameConfig.thugMaxHealth) {
      final hpPct = (health / GameConfig.thugMaxHealth).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(-20, -h - 12, 40, 6), _hpBgPaint);
      canvas.drawRect(Rect.fromLTWH(-19, -h - 11, 38 * hpPct, 4), _hpFgPaint);
    }

    if (patrolDirection < 0) {
      canvas.restore();
    }
  }
}
