import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:spideyhood/game/actors/enemies/minion_with_gun.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/pickup_drop.dart';
import 'package:spideyhood/game/components/web_anchor_point.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/moonlit_rooftop_background.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

/// Story Quest Stage 2: Moonlit Rooftop Cityscape.
class MoonlitRooftopGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapCallbacks {
  late final Spidey player;
  late final MinionWithGun gunMinion;
  final List<WebAnchorPoint> anchors = [];
  final List<WarehousePlatform> platforms = [];

  VoidCallback? onExitToMenu;
  VoidCallback? onRestartPart;
  VoidCallback? onRestartStory;
  VoidCallback? onMissionComplete;

  static const double mapWidth = MoonlitRooftopBackground.mapWidth; // 2172.0
  static const double mapHeight = MoonlitRooftopBackground.mapHeight; // 724.0

  // Zoomed out camera settings so player can see more of the cityscape skyline
  static const double targetVisibleHeight = 420.0;
  static const double targetSwingVisibleHeight = 520.0;

  // Platform Supply Drops (Max 3 active in arena)
  static const int maxActiveDrops = 3;
  double _dropSpawnTimer = 0.0;
  final math.Random _random = math.Random();

  // Control state
  bool isLeftPressed = false;
  bool isRightPressed = false;
  double _currentSwingZoomTarget = GameConfig.streetZoom;
  bool _wasSwingingLastFrame = false;

  static double responsiveStreetZoom(double screenHeight) {
    if (screenHeight <= 0) return 1.15;
    return screenHeight / targetVisibleHeight;
  }

  static double responsiveSwingZoom(double screenHeight) {
    if (screenHeight <= 0) return 0.95;
    return screenHeight / targetSwingVisibleHeight;
  }

  @override
  Color backgroundColor() => const Color(0xFF070B19);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      if (!AudioManager.instance.isMuted && !AudioManager.instance.isPlaying) {
        AudioManager.instance.playBgm();
      }
    } catch (_) {}

    // 1. Background Environment (2172 x 724)
    world.add(MoonlitRooftopBackground());

    // 2. Rooftop Platforms accurately leveled to visual rooftop parapets:
    // Building 1 (left): x: 0..195, y: 428.0
    // Building 2: x: 316..531, y: 506.0
    // Building 3 (main): x: 670..900, y: 430.0
    // Building 3 (ledge): x: 888..1023, y: 520.0
    // Building 4 (roof below billboard): x: 1208..1453, y: 472.0
    // Building 4 (billboard top): x: 1208..1453, y: 370.0
    // Building 5 (radio tower): x: 1635..1855, y: 470.0
    // Building 6 (right): x: 1980..2172, y: 442.0
    platforms.addAll([
      WarehousePlatform(position: Vector2(0, 428), size: Vector2(195, 24)),
      WarehousePlatform(position: Vector2(316, 506), size: Vector2(215, 24)),
      WarehousePlatform(position: Vector2(670, 430), size: Vector2(230, 24)),
      WarehousePlatform(position: Vector2(888, 520), size: Vector2(135, 24)),
      WarehousePlatform(position: Vector2(1208, 472), size: Vector2(245, 24)),
      WarehousePlatform(position: Vector2(1208, 370), size: Vector2(245, 20)),
      WarehousePlatform(position: Vector2(1635, 470), size: Vector2(220, 24)),
      WarehousePlatform(position: Vector2(1980, 442), size: Vector2(192, 24)),
    ]);

    for (final p in platforms) {
      world.add(p);
    }

    // 3. Web Anchor Points in the Night Sky for dynamic rooftop swinging
    final anchorCoordinates = [
      // Rooftop sky anchors
      Vector2(90, 160),
      Vector2(250, 190),  // Gap 1
      Vector2(420, 210),
      Vector2(600, 200),  // Gap 2
      Vector2(790, 170),
      Vector2(950, 210),
      Vector2(1110, 190), // Gap 3
      Vector2(1320, 180),
      Vector2(1540, 200), // Gap 4
      Vector2(1740, 170),
      Vector2(1920, 190), // Gap 5
      Vector2(2080, 160),
      // Upper skyline anchors
      Vector2(180, 100),
      Vector2(500, 90),
      Vector2(850, 80),
      Vector2(1200, 85),
      Vector2(1600, 95),
      Vector2(1980, 90),
    ];

    for (final coord in anchorCoordinates) {
      final anchor = WebAnchorPoint(position: coord);
      anchors.add(anchor);
      world.add(anchor);
    }

    // 4. Hero Spawn: Spawns directly on the first platform (x = 80, y = 428)
    player = Spidey(
      position: Vector2(80, 428),
      groundLevel: mapHeight,
    );
    player.isGrounded = true;
    player.currentPlatform = platforms.first;
    world.add(player);

    // 5. Initial Rooftop Supply Drops
    _spawnDropAt(Vector2(420, 506), DropType.webFluid);
    _spawnDropAt(Vector2(1320, 472), DropType.heal);

    // 6. Rooftop Patrol Guards on intermediate buildings
    final guardPositions = [
      Vector2(780, 430),
      Vector2(1350, 472),
      Vector2(1750, 470),
    ];
    for (int i = 0; i < guardPositions.length; i++) {
      final guard = ViperGuard(
        position: guardPositions[i],
        groundLevel: mapHeight,
        patrolRange: 100.0,
      );
      guard.currentPlatform = _findPlatformAt(guardPositions[i].x, guardPositions[i].y);
      guard.isGrounded = true;
      world.add(guard);
    }

    // 7. Marksman Minion (minion_wgun) on the Last Building (Platform 8: 1980..2172, y = 442)
    gunMinion = MinionWithGun(
      position: Vector2(2080, 442),
      groundLevel: mapHeight,
      minPatrolX: 2010.0,
      maxPatrolX: 2150.0,
      onDefeated: () {
        // Final sniper defeated on the rooftop!
        Future.delayed(const Duration(milliseconds: 1200), () {
          onMissionComplete?.call();
        });
      },
    );
    gunMinion.currentPlatform = _findPlatformAt(2080, 442);
    gunMinion.isFacingRight = false; // Aims left towards Spidey's approach
    world.add(gunMinion);

    // 8. Camera Configuration
    camera.viewfinder.anchor = const Anchor(0.5, 0.65);
    camera.viewfinder.zoom = responsiveStreetZoom(size.y);
  }

  WarehousePlatform? _findPlatformAt(double x, [double? y]) {
    WarehousePlatform? best;
    double minDy = double.infinity;
    for (final p in platforms) {
      if (x >= p.position.x && x <= p.position.x + p.size.x) {
        if (y == null) return p;
        final dy = (p.position.y - y).abs();
        if (dy < minDy) {
          minDy = dy;
          best = p;
        }
      }
    }
    return best;
  }

  void _spawnDropAt(Vector2 pos, DropType type) {
    final drop = PickupDrop(
      position: pos,
      type: type,
      groundLevel: pos.y,
    );
    world.add(drop);
  }

  void _spawnRandomDrop() {
    final activeDrops = world.children.whereType<PickupDrop>().length;
    if (activeDrops >= maxActiveDrops) return;

    // Pick random platform (platforms 1..6)
    final platIdx = _random.nextInt(platforms.length);
    final plat = platforms[platIdx];
    final dropX = plat.position.x + 30.0 + _random.nextDouble() * math.max(10.0, plat.size.x - 60.0);
    final dropY = plat.position.y;

    final typeRoll = _random.nextInt(3);
    final type = typeRoll == 0
        ? DropType.heal
        : (typeRoll == 1 ? DropType.webFluid : DropType.shield);

    _spawnDropAt(Vector2(dropX, dropY), type);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Periodic supply drops spawning on rooftops
    _dropSpawnTimer += dt;
    if (_dropSpawnTimer >= 10.0) {
      _dropSpawnTimer = 0.0;
      _spawnRandomDrop();
    }

    // Safety Alley Pit Check: If Spidey falls below rooftops without a web attachment
    if (player.position.y > 680.0 && player.state != SpideyState.swinging) {
      _handlePitFall();
    }

    // Process horizontal movement
    if (player.state != SpideyState.swinging) {
      if (isLeftPressed && !isRightPressed) {
        player.move(-1.0);
      } else if (isRightPressed && !isLeftPressed) {
        player.move(1.0);
      } else if (!isLeftPressed && !isRightPressed && player.state == SpideyState.running) {
        player.move(0.0);
      }
    }

    // Camera following & responsive zoom
    _updateCamera(dt);
  }

  void _handlePitFall() {
    // Find closest platform
    WarehousePlatform nearest = platforms.first;
    double minD = (player.position.x - (nearest.position.x + nearest.size.x * 0.5)).abs();
    for (final p in platforms) {
      final d = (player.position.x - (p.position.x + p.size.x * 0.5)).abs();
      if (d < minD) {
        minD = d;
        nearest = p;
      }
    }

    // Respawn on nearest platform
    player.position = Vector2(nearest.position.x + nearest.size.x * 0.5, nearest.position.y);
    player.velocity = Vector2.zero();
    player.isGrounded = true;
    player.currentPlatform = nearest;
    player.state = SpideyState.idle;
    player.takeDamage(10); // 1 heart penalty
    AudioManager.instance.playWebShoot();
  }

  void _updateCamera(double dt) {
    final baseStreetZoom = responsiveStreetZoom(size.y);
    final baseSwingZoom = responsiveSwingZoom(size.y);
    final isSwinging = (player.state == SpideyState.swinging);

    if (isSwinging) {
      if (!_wasSwingingLastFrame) {
        _currentSwingZoomTarget = camera.viewfinder.zoom;
      }
      _currentSwingZoomTarget = math.max(
        baseSwingZoom,
        _currentSwingZoomTarget - (dt * 1.15),
      );
    } else {
      _currentSwingZoomTarget = baseStreetZoom;
    }
    _wasSwingingLastFrame = isSwinging;

    final targetZoom = _currentSwingZoomTarget;
    final zoomSpeed = isSwinging ? 2.2 : 1.6;
    camera.viewfinder.zoom += (targetZoom - camera.viewfinder.zoom) * (zoomSpeed * dt).clamp(0.0, 1.0);

    final targetAnchorY = isSwinging ? 0.65 : 0.72;
    final currentAnchorY = camera.viewfinder.anchor.y;
    final newAnchorY = currentAnchorY + (targetAnchorY - currentAnchorY) * (2.0 * dt).clamp(0.0, 1.0);
    camera.viewfinder.anchor = Anchor(0.5, newAnchorY);

    // Keep camera smoothly within skyline boundaries with zoomed-out visible window
    final zoom = math.max(0.1, camera.viewfinder.zoom);
    final halfVisibleW = (size.x * 0.5) / zoom;
    final halfVisibleH = (size.y * 0.5) / zoom;
    final minCamX = math.min(mapWidth * 0.5, halfVisibleW);
    final maxCamX = math.max(mapWidth * 0.5, mapWidth - halfVisibleW);
    final camX = player.position.x.clamp(minCamX, maxCamX);

    final minCamY = math.min(mapHeight * 0.5, halfVisibleH * 0.7);
    final maxCamY = math.max(mapHeight * 0.5, mapHeight - (halfVisibleH * 0.3));
    final camY = (player.position.y - 20.0).clamp(minCamY, maxCamY);
    camera.viewfinder.position = Vector2(camX, camY);
  }

  // --- Touch & Keyboard Controls ---

  void onLeftDown() {
    isLeftPressed = true;
    player.move(-1.0);
  }

  void onLeftUp() {
    isLeftPressed = false;
    player.move(isRightPressed ? 1.0 : 0.0);
  }

  void onRightDown() {
    isRightPressed = true;
    player.move(1.0);
  }

  void onRightUp() {
    isRightPressed = false;
    player.move(isLeftPressed ? -1.0 : 0.0);
  }

  void startMoveLeft() => onLeftDown();
  void startMoveRight() => onRightDown();
  void stopMove() {
    isLeftPressed = false;
    isRightPressed = false;
    player.move(0.0);
  }

  void onJumpPress() {
    player.jump();
  }

  void jump() => onJumpPress();

  void dropDownPlatform() {
    player.dropDownPlatform();
  }

  void onPunchPress() {
    player.punch();
  }

  void punch() => onPunchPress();

  void onKickPress() {
    player.kick();
  }

  void kick() => onKickPress();

  void onSkill1Press() {
    player.useSkill1();
  }

  void useSkill() => onSkill1Press();

  void onSwingDown() {
    if (player.state != SpideyState.swinging) {
      _attachNearestWebAnchor();
    }
  }

  void onSwingUp() {
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
    }
  }

  void shootWebAhead() {
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
      return;
    }
    _attachNearestWebAnchor();
  }

  void _attachNearestWebAnchor() {
    WebAnchorPoint? bestAnchor;
    double bestScore = double.infinity;
    final dir = player.isFacingRight ? 1.0 : -1.0;

    for (final a in anchors) {
      final dx = a.position.x - player.position.x;
      final dy = a.position.y - player.position.y;
      if (dy >= -20) continue; // Must be overhead

      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 40.0 || dist > 450.0) continue;

      final isForward = (dx * dir) > -30.0;
      final score = dist - (isForward ? 70.0 : 0.0);
      if (score < bestScore) {
        bestScore = score;
        bestAnchor = a;
      }
    }

    if (bestAnchor != null) {
      player.shootWeb(bestAnchor.position.clone());
    } else {
      // Automatic overhead swing point
      final fallbackX = player.position.x + (player.isFacingRight ? 120.0 : -120.0);
      final fallbackY = math.max(60.0, player.position.y - 180.0);
      player.shootWeb(Vector2(fallbackX, fallbackY));
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    isLeftPressed = keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    isRightPressed = keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.space) {
        player.jump();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyS ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        dropDownPlatform();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyJ) {
        player.punch();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyK) {
        player.kick();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyU) {
        player.useSkill1();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyL ||
          event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        onSwingDown();
        return KeyEventResult.handled;
      }
    }

    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyL ||
          event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        onSwingUp();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
