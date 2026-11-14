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
import 'package:spideyhood/game/story/harbor_background.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

/// Story Mode Part 3: Manhattan Harbor Docks & Cargo Ship Deck.
/// Features wide panoramic harbor environment (2172 x 724), dock platforms,
/// cargo container stacks, crane anchors, and waterfront combat.
class HarborGame extends FlameGame with HasCollisionDetection, KeyboardEvents {
  static const double mapWidth = HarborBackground.mapWidth; // 2172.0
  static const double mapHeight = HarborBackground.mapHeight; // 724.0

  // Zoomed out camera settings so player can see more of the harbor and cranes
  static const double targetVisibleHeight = 420.0;
  static const double targetSwingVisibleHeight = 520.0;

  // Platform Supply Drops
  static const int maxActiveDrops = 3;
  double _dropSpawnTimer = 0.0;
  final math.Random _random = math.Random();

  // Control state
  bool isLeftPressed = false;
  bool isRightPressed = false;
  double _currentSwingZoomTarget = GameConfig.streetZoom;
  bool _wasSwingingLastFrame = false;

  late final Spidey player;
  final List<WarehousePlatform> platforms = [];
  final List<WebAnchorPoint> anchors = [];
  late final MinionWithGun shipMarksman;

  int defeatedEnemies = 0;
  final int totalEnemies = 4; // 3 Dock guards + 1 Ship marksman
  bool hasCompleted = false;

  VoidCallback? onMissionComplete;
  VoidCallback? onRestartPart;
  VoidCallback? onRestartStory;
  VoidCallback? onExitToMenu;

  static double responsiveStreetZoom(double screenHeight) =>
      screenHeight / targetVisibleHeight;

  static double responsiveSwingZoom(double screenHeight) =>
      screenHeight / targetSwingVisibleHeight;

  @override
  Color backgroundColor() => const Color(0xFF0A192F);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      if (!AudioManager.instance.isMuted && !AudioManager.instance.isPlaying) {
        AudioManager.instance.playBgm();
      }
    } catch (_) {}

    // 1. Background Environment (2172 x 724)
    world.add(HarborBackground());

    // 2. Harbor Pier Platforms, Shipping Docks, and Cargo Containers:
    platforms.addAll([
      // Pier 1 (Start dock): x = 0..320, surface y = 560
      WarehousePlatform(position: Vector2(0, 560), size: Vector2(320, mapHeight - 560)),
      // Pier 2 (Cargo dock): x = 430..710, surface y = 560
      WarehousePlatform(position: Vector2(430, 560), size: Vector2(280, mapHeight - 560)),
      // Container Stack 1: elevated catwalk on Pier 2
      WarehousePlatform(position: Vector2(490, 480), size: Vector2(160, 24)),
      // Pier 3 (Central dock): x = 830..1190, surface y = 560
      WarehousePlatform(position: Vector2(830, 560), size: Vector2(360, mapHeight - 560)),
      // Container Stack 2: elevated catwalk on Pier 3
      WarehousePlatform(position: Vector2(910, 470), size: Vector2(180, 24)),
      // Pier 4 (Crane terminal): x = 1300..1640, surface y = 560
      WarehousePlatform(position: Vector2(1300, 560), size: Vector2(340, mapHeight - 560)),
      // Cargo Ship Deck (Pier 5): x = 1760..2172, surface y = 540
      WarehousePlatform(position: Vector2(1760, 540), size: Vector2(412, mapHeight - 540)),
      // Ship Bridge / Cabin Roof
      WarehousePlatform(position: Vector2(1890, 450), size: Vector2(190, 24)),
    ]);

    for (final p in platforms) {
      world.add(p);
    }

    // 3. Web Anchor Points on Harbor Cranes, Cargo Booms & Masts
    final anchorCoordinates = [
      Vector2(160, 220),
      Vector2(370, 200), // Gap 1
      Vector2(570, 210),
      Vector2(770, 190), // Gap 2
      Vector2(1000, 200),
      Vector2(1240, 180), // Gap 3
      Vector2(1480, 210),
      Vector2(1700, 190), // Gap 4
      Vector2(1920, 180),
      Vector2(2080, 190),
      // Skyline crane anchor tops
      Vector2(260, 120),
      Vector2(700, 110),
      Vector2(1150, 100),
      Vector2(1580, 115),
      Vector2(1980, 110),
    ];

    for (final coord in anchorCoordinates) {
      final anchor = WebAnchorPoint(position: coord);
      anchors.add(anchor);
      world.add(anchor);
    }

    // 4. Hero Spawn: Spawns on Pier 1 (x = 80, y = 560)
    player = Spidey(
      position: Vector2(80, 560),
      groundLevel: mapHeight,
    );
    player.maxHearts = 3;
    player.health = 3;
    player.allowHealthRegen = false;
    player.maxWebDistanceOverride = 120.0;
    player.maxSwingDuration = 1.0;
    player.swingCooldownMax = 1.8;
    player.swingReleaseFactor = 0.50;
    player.skillShotHeightOffset = 14.0;
    player.isGrounded = true;
    player.currentPlatform = platforms.first;
    world.add(player);

    // 5. Supply Drops on Harbor Docks
    _spawnDropAt(Vector2(570, 480), DropType.webFluid);
    _spawnDropAt(Vector2(1450, 560), DropType.shield);

    // 6. Dock Patrol Guards (3 guards across intermediate piers)
    final guardPositions = [
      Vector2(550, 560),  // Pier 2
      Vector2(1010, 560), // Pier 3
      Vector2(1450, 560), // Pier 4
    ];

    for (int i = 0; i < guardPositions.length; i++) {
      final guard = ViperGuard(
        position: guardPositions[i],
        groundLevel: mapHeight,
        patrolRange: 110.0,
        standingOffsetY: 0.0,
        onDefeated: () {
          defeatedEnemies++;
          checkMissionCompletion();
        },
      );
      guard.currentPlatform = _findPlatformAt(guardPositions[i].x, guardPositions[i].y);
      guard.isGrounded = true;
      world.add(guard);
    }

    // 7. Marksman Minion on the Cargo Ship Deck (Positioned at 2000, 540)
    shipMarksman = MinionWithGun(
      position: Vector2(2000, 540),
      groundLevel: mapHeight,
      minPatrolX: 1900.0,
      maxPatrolX: 2120.0,
      onDefeated: () {
        defeatedEnemies++;
        checkMissionCompletion();
      },
    );
    shipMarksman.currentPlatform = _findPlatformAt(2000, 540);
    shipMarksman.isFacingRight = false; // Aims left towards approaching hero
    world.add(shipMarksman);

    // 8. Camera Viewport Configuration
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
    final currentDrops = world.children.whereType<PickupDrop>().length;
    if (currentDrops >= maxActiveDrops) return;

    final platIdx = _random.nextInt(platforms.length);
    final plat = platforms[platIdx];
    final dropX = plat.position.x + 30.0 + _random.nextDouble() * math.max(10.0, plat.size.x - 60.0);
    final dropY = plat.position.y;

    final typeRoll = _random.nextInt(2);
    final type = typeRoll == 0 ? DropType.webFluid : DropType.shield;
    _spawnDropAt(Vector2(dropX, dropY), type);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _dropSpawnTimer += dt;
    if (_dropSpawnTimer >= 10.0) {
      _dropSpawnTimer = 0.0;
      _spawnRandomDrop();
    }

    // Water pit fall check: Spidey plunges to bottom of harbor water before respawning
    if (player.position.y >= mapHeight - 4.0 && player.state != SpideyState.swinging) {
      _handleWaterFall();
    }

    // Horizontal movement
    if (player.state != SpideyState.swinging) {
      if (isLeftPressed && !isRightPressed) {
        player.move(-1.0);
      } else if (isRightPressed && !isLeftPressed) {
        player.move(1.0);
      } else if (!isLeftPressed && !isRightPressed && player.state == SpideyState.running) {
        player.move(0.0);
      }
    }

    _updateCamera(dt);
  }

  void _handleWaterFall() {
    // Respawn Spidey at Pier 1 dock
    player.position = Vector2(80, 560);
    player.velocity = Vector2.zero();
    player.isGrounded = true;
    player.currentPlatform = platforms.first;
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

    // Keep camera smoothly within harbor boundaries - no clipping or top/bottom border bars
    final zoom = math.max(0.1, camera.viewfinder.zoom);
    final minCamX = (camera.viewfinder.anchor.x * size.x) / zoom;
    final maxCamX = mapWidth - ((1.0 - camera.viewfinder.anchor.x) * size.x) / zoom;
    final camX = minCamX >= maxCamX
        ? mapWidth * 0.5
        : player.position.x.clamp(minCamX, maxCamX);

    final minCamY = (camera.viewfinder.anchor.y * size.y) / zoom;
    final maxCamY = mapHeight - ((1.0 - camera.viewfinder.anchor.y) * size.y) / zoom;
    final camY = minCamY >= maxCamY
        ? mapHeight * 0.5
        : (player.position.y - 20.0).clamp(minCamY, maxCamY);
    camera.viewfinder.position = Vector2(camX, camY);
  }

  // Touch and Keyboard Controls
  void startMoveLeft() {
    isLeftPressed = true;
    player.move(-1.0);
  }

  void startMoveRight() {
    isRightPressed = true;
    player.move(1.0);
  }

  void stopMove() {
    isLeftPressed = false;
    isRightPressed = false;
    player.move(0.0);
  }

  void jump() => player.jump();

  void dropDownPlatform() => player.dropDownPlatform();

  void punch() => player.punch();

  void kick() => player.kick();

  void useSkill() => player.useSkill1();

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
      if (dy >= -20) continue;

      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 20.0 || dist > 210.0) continue;

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
      final fallbackX = player.position.x + (player.isFacingRight ? 50.0 : -50.0);
      final fallbackY = math.max(60.0, player.position.y - 95.0);
      player.shootWeb(Vector2(fallbackX, fallbackY));
    }
  }

  void checkMissionCompletion() {
    if (hasCompleted) return;
    if (defeatedEnemies >= totalEnemies) {
      hasCompleted = true;
      AudioManager.instance.playWebShoot();
      Future.delayed(const Duration(milliseconds: 1200), () {
        onMissionComplete?.call();
      });
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
