import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Elevated industrial platform inside the Abandoned Warehouse.
/// Completely invisible collision surface matching the background artwork.
class WarehousePlatform extends PositionComponent with CollisionCallbacks {
  WarehousePlatform({
    required Vector2 position,
    required Vector2 size,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    // Intentionally invisible so the underlying background artwork is seen seamlessly
  }
}
