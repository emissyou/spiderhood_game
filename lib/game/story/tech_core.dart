import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/services/audio_manager.dart';

/// Stolen Compound-V Vial collectible in the warehouse (replaces military tech cores).
class TechCore extends PositionComponent with CollisionCallbacks {
  final int coreId;
  final void Function(int coreId)? onCollected;

  double _animTime = 0.0;
  bool isCollected = false;
  Sprite? _compoundVSprite;

  TechCore({
    required Vector2 position,
    required this.coreId,
    this.onCollected,
  }) : super(
          position: position,
          size: Vector2(26, 34),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    try {
      _compoundVSprite = await Sprite.load('drop/compound-v.png');
    } catch (_) {
      _compoundVSprite = null;
    }
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

      onCollected?.call(coreId);
      Future.microtask(() {
        if (isMounted) removeFromParent();
      });
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Smooth floating bobbing motion (floating higher above platform surface)
    final bobY = (math.sin(_animTime * 3.8) * 3.5) - 12.0;

    if (_compoundVSprite != null) {
      _compoundVSprite!.render(
        canvas,
        position: Vector2(-size.x * 0.5, -size.y + bobY),
        size: size,
      );
    } else {
      // Fallback vial vector without circles
      final vialRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(-size.x * 0.5 + 4, -size.y + 4 + bobY, size.x - 8, size.y - 8),
        const Radius.circular(5),
      );
      final p = Paint()..color = const Color(0xFFA855F7);
      canvas.drawRRect(vialRect, p);
    }
  }
}

