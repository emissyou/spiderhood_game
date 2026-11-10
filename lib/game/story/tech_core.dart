import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/comic_fx.dart';
import 'package:spideyhood/game/services/audio_manager.dart';

/// Glowing Viper Tech Core collectible in the warehouse.
class TechCore extends PositionComponent with CollisionCallbacks {
  final int coreId;
  final void Function(int coreId)? onCollected;

  double _animTime = 0.0;
  bool isCollected = false;

  static final Paint _chassisPaint = Paint()..color = const Color(0xFF1E293B);
  static final Paint _borderPaint = Paint()
    ..color = const Color(0xFF00F0FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final Paint _vPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _coreGlowPaint = Paint();

  late final RRect _canisterRect;
  late final RRect _crystalRect;
  late final Path _vPath;

  TechCore({
    required Vector2 position,
    required this.coreId,
    this.onCollected,
  }) : super(
          position: position,
          size: Vector2(28, 36),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    _canisterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.x - 8, size.y - 8),
      const Radius.circular(6),
    );
    _crystalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 10, size.x - 16, size.y - 20),
      const Radius.circular(3),
    );
    _vPath = Path()
      ..moveTo(size.x / 2 - 4, size.y / 2 - 3)
      ..lineTo(size.x / 2, size.y / 2 + 4)
      ..lineTo(size.x / 2 + 4, size.y / 2 - 3);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (!isCollected && other is Spidey) {
      isCollected = true;
      AudioManager.instance.playSfx('sfx/button_click_2.wav', volume: 0.9);

      parent?.add(
        ComicFx(
          text: 'TECH ACQUIRED!',
          position: position - Vector2(0, 30),
          badgeColor: const Color(0xFF00F0FF),
        ),
      );

      onCollected?.call(coreId);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Floating bobbing motion
    final bobY = math.sin(_animTime * 3.5) * 4.0;
    final pulse = (math.sin(_animTime * 5.0) + 1.0) / 2.0;

    canvas.save();
    canvas.translate(0, bobY);

    // Outer cyan glow aura
    _glowPaint.color = const Color(0xFF00F0FF).withValues(alpha: 0.25 + pulse * 0.25);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 18 + pulse * 3, _glowPaint);

    // Canister metallic chassis
    canvas.drawRRect(_canisterRect, _chassisPaint);
    canvas.drawRRect(_canisterRect, _borderPaint);

    // Glowing core crystal
    _coreGlowPaint.color = Color.lerp(const Color(0xFF00F0FF), Colors.white, pulse)!;
    canvas.drawRRect(_crystalRect, _coreGlowPaint);

    // Viper Tech Symbol (small dark V)
    canvas.drawPath(_vPath, _vPaint);

    canvas.restore();
  }
}
