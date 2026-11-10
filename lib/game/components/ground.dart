import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:spideyhood/game/config/game_config.dart';

/// Solid ground floor following exact image boundaries (0 to 2086).
class Ground extends PositionComponent with CollisionCallbacks {
  Ground()
      : super(
          position: Vector2(0, GameConfig.groundY),
          size: Vector2(GameConfig.bgWidth, 150),
          anchor: Anchor.topLeft,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
