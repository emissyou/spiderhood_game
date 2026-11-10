import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/web_anchor_point.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/tech_core.dart';
import 'package:spideyhood/game/story/warehouse_background.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

/// Story Quest 1: Infiltrate The Vipers' Abandoned Warehouse.
class WarehouseGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapCallbacks {
  late final Spidey player;
  late final ViperBoss boss;
  final List<WebAnchorPoint> anchors = [];

  VoidCallback? onExitToMenu;
  VoidCallback? onMissionComplete;
  VoidCallback? onTriggerEscapeScenario;
  bool hasTriggeredEscapeScenario = false;

  // Quest 1 Objectives Tracker
  int defeatedGuards = 0;
  static const int targetGuards = 4;

  int collectedCores = 0;
  static const int targetCores = 3;

  bool terminalReached = false;
  bool isMissionComplete = false;

  // Entrance swing and boss meeting cutscene state
  bool isEntranceCutscene = true;
  int cutscenePhase = 0; // 0: Spidey enters, 1: Pan to boss, 2: Boss meeting dialogue, 3: Pan to Spidey, 4: Done
  double _cutsceneTimer = 0.0;
  String? cutsceneBanner;
  bool hasPlayerEngaged = false;
  double _entranceTimer = 0.0;

  // Key tracking
  bool isLeftPressed = false;
  bool isRightPressed = false;
  double _currentSwingZoomTarget = GameConfig.streetZoom;
  bool _wasSwingingLastFrame = false;

  static const double warehouseFloorY = 496.0;
  static const double warehouseWorldWidth = 2048.0;
  static const double warehouseWorldHeight = 508.0;
  static const double targetVisibleHeight = 230.0;
  static const double targetSwingVisibleHeight = 320.0;

  static double responsiveStreetZoom(double screenHeight) {
    if (screenHeight <= 0) return 2.0;
    return screenHeight / targetVisibleHeight;
  }

  static double responsiveSwingZoom(double screenHeight) {
    if (screenHeight <= 0) return 1.4;
    return screenHeight / targetSwingVisibleHeight;
  }

  @override
  Color backgroundColor() => const Color(0xFF10121A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Ensure background music is active for the story mission
    if (!AudioManager.instance.isMuted && !AudioManager.instance.isPlaying) {
      AudioManager.instance.playBgm();
    }

    // 1. Warehouse Background (2048 x 508)
    world.add(WarehouseBackground());

    // 2. Elevated Industrial Catwalks (Completely invisible collision hitboxes matching background art)
    // Left platform moved up to y=320; Center platform moved down to y=364 to match wooden deck
    final platforms = [
      WarehousePlatform(position: Vector2(40, 320), size: Vector2(320, 20)),
      WarehousePlatform(position: Vector2(620, 364), size: Vector2(780, 20)),
    ];
    for (final p in platforms) {
      world.add(p);
    }

    // 3. High Ceiling Web Anchor Trusses for high-speed swinging across rafters
    final rafterXPositions = [
      140.0, 290.0, 460.0, 630.0, 800.0, 970.0, 1140.0,
      1310.0, 1480.0, 1650.0, 1820.0, 1960.0,
    ];
    for (int i = 0; i < rafterXPositions.length; i++) {
      final y = 110.0 + (i % 2 == 0 ? 0 : 25.0);
      final anchor = WebAnchorPoint(position: Vector2(rafterXPositions[i], y));
      anchors.add(anchor);
      world.add(anchor);
    }

    // 4. Stolen Military Tech Cores (Collectibles)
    final corePositions = [
      Vector2(200, 295),   // On Left Catwalk Platform (y = 320)
      Vector2(1000, 339),  // On Central Assembly Bridge (y = 364)
      Vector2(1750, 470),  // In Deep Sector Terminal area (floor y = 496)
    ];
    for (int i = 0; i < corePositions.length; i++) {
      world.add(
        TechCore(
          position: corePositions[i],
          coreId: i + 1,
          onCollected: (_) {
            collectedCores++;
            _checkQuestCompletion();
          },
        ),
      );
    }

    // 5. Boss: Viper Warlord meeting his minions on the center catwalk bridge (y = 364)
    boss = ViperBoss(
      position: Vector2(1050.0, 364.0),
      size: Vector2(38, 68),
      groundLevel: warehouseFloorY,
    );
    boss.currentPlatform = platforms[1];
    world.add(boss);

    // Initial syndicate guards gathered in a military lineup facing the boss on the center bridge
    final guardConfigs = [
      (x: 840.0, y: 364.0, range: 80.0, ground: warehouseFloorY, dir: 1.0),
      (x: 910.0, y: 364.0, range: 80.0, ground: warehouseFloorY, dir: 1.0),
      (x: 980.0, y: 364.0, range: 80.0, ground: warehouseFloorY, dir: 1.0),
      (x: 1140.0, y: 364.0, range: 80.0, ground: warehouseFloorY, dir: -1.0),
    ];
    for (final cfg in guardConfigs) {
      final guard = ViperGuard(
        position: Vector2(cfg.x, cfg.y),
        patrolRange: cfg.range,
        groundLevel: cfg.ground,
        size: Vector2(28, 50),
        onDefeated: () {
          defeatedGuards++;
          checkAllMinionsDefeated();
        },
      );
      guard.patrolDirection = cfg.dir;
      guard.currentPlatform = platforms[1];
      guard.isGrounded = true;
      guard.velocity.setZero();
      guard.state = MinionState.idle;
      world.add(guard);
    }

    // 6. Spawn Spidey swinging in from the entrance rafter
    final entranceAnchor = Vector2(160.0, 110.0);
    player = Spidey(
      position: Vector2(40.0, 250.0),
      size: Vector2(28, 50),
      groundLevel: warehouseFloorY,
      worldWidth: warehouseWorldWidth,
    );
    world.add(player);

    // Initialize Spider-Man in an entrance swing swooping down towards the floor
    player.webAnchor = entranceAnchor;
    player.webLength = (player.position - entranceAnchor).length;
    final offset = (player.position - Vector2(0, player.size.y / 2)) - entranceAnchor;
    player.swingAngle = math.atan2(offset.x, offset.y);
    player.angularVelocity = 3.2;
    player.state = SpideyState.swinging;
    player.isGrounded = false;
    player.isFacingRight = true;
    AudioManager.instance.playWebShoot();

    // 7. Camera framing
    final initialZoom = hasLayout ? responsiveStreetZoom(size.y) : 2.0;
    _currentSwingZoomTarget = initialZoom;
    camera.viewfinder.anchor = const Anchor(0.5, 0.85);
    camera.viewfinder.zoom = initialZoom;
    camera.viewfinder.position = Vector2(player.position.x, player.position.y);
  }

  void checkAllMinionsDefeated() {
    final aliveMinions = world.children.whereType<ViperGuard>().where((g) => !g.isDefeated).length;
    if (aliveMinions == 0 && boss.bossState == BossState.waitingRightInvulnerable) {
      boss.bossState = BossState.summoningPhase1;
      cutsceneBanner = "VIPER WARLORD: 'Incompetent worms! I will crush you myself!'";
      Future.delayed(const Duration(seconds: 3), () {
        if (cutsceneBanner != null && cutsceneBanner!.startsWith("VIPER WARLORD:")) {
          cutsceneBanner = null;
        }
      });
    }
    _checkQuestCompletion();
  }

  void engagePlayer() {
    if (isEntranceCutscene) {
      isEntranceCutscene = false;
      cutscenePhase = 4;
      cutsceneBanner = null;
    }
    if (!hasPlayerEngaged) {
      hasPlayerEngaged = true;
      boss.onPlayerEngaged();
      cutsceneBanner = "THE SYNDICATE IS ALERTED!";
      Future.delayed(const Duration(seconds: 2), () {
        if (cutsceneBanner == "THE SYNDICATE IS ALERTED!") {
          cutsceneBanner = null;
        }
      });
    }
  }

  void _checkQuestCompletion() {
    if (isMissionComplete) return;

    final bossDone = (boss.bossState == BossState.escaped || !boss.isMounted);
    if (defeatedGuards >= targetGuards && collectedCores >= targetCores && terminalReached && bossDone) {
      isMissionComplete = true;
      onMissionComplete?.call();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final baseZoom = responsiveStreetZoom(size.y);
      if (player.state != SpideyState.swinging) {
        camera.viewfinder.zoom = baseZoom;
        _currentSwingZoomTarget = baseZoom;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cutscene sequence:
    // Phase 0: Spider-Man swoops down on entrance web and lands on floor
    // Phase 1: Camera glides smoothly across the warehouse to the Boss meeting his minions
    // Phase 2: Boss meeting dialogue and scene focus
    // Phase 3: Camera glides smoothly back to Spider-Man
    // Phase 4: Cinematic finished -> Player takes control!
    if (isEntranceCutscene) {
      _entranceTimer += dt;

      if (cutscenePhase == 0) {
        if (player.state == SpideyState.swinging) {
          if (player.swingAngle >= 0.16 || player.position.y >= warehouseFloorY - 70.0) {
            player.releaseWeb(withBoost: false);
            player.velocity.x = 220.0;
            player.velocity.y = 60.0;
          }
        } else {
          if (player.isGrounded || player.position.y >= warehouseFloorY - 2.0) {
            player.position.y = warehouseFloorY;
            player.velocity.setZero();
            player.state = SpideyState.idle;
            player.isGrounded = true;
            cutscenePhase = 1;
            _cutsceneTimer = 0.0;
            AudioManager.instance.playJump();
          }
        }

        if (_entranceTimer > 2.8 && cutscenePhase == 0) {
          if (player.state == SpideyState.swinging) {
            player.releaseWeb(withBoost: false);
          }
          player.position.y = warehouseFloorY;
          player.velocity.setZero();
          player.state = SpideyState.idle;
          player.isGrounded = true;
          cutscenePhase = 1;
          _cutsceneTimer = 0.0;
        }
      } else if (cutscenePhase == 1) {
        _cutsceneTimer += dt;
        if (_cutsceneTimer >= 2.0) {
          cutscenePhase = 2;
          _cutsceneTimer = 0.0;
          cutsceneBanner = "VIPER WARLORD: 'Secure the military tech cores! Destroy anyone who interferes!'";
        }
      } else if (cutscenePhase == 2) {
        _cutsceneTimer += dt;
        if (_cutsceneTimer >= 2.4) {
          cutscenePhase = 3;
          _cutsceneTimer = 0.0;
          cutsceneBanner = null;
        }
      } else if (cutscenePhase == 3) {
        _cutsceneTimer += dt;
        if (_cutsceneTimer >= 1.8) {
          cutscenePhase = 4;
          isEntranceCutscene = false;
          cutsceneBanner = "MOVE OR ATTACK TO ENGAGE!";
          Future.delayed(const Duration(seconds: 3), () {
            if (cutsceneBanner == "MOVE OR ATTACK TO ENGAGE!") {
              cutsceneBanner = null;
            }
          });
        }
      }
    }

    // Check terminal arrival at the deep sector of the warehouse
    if (!terminalReached && player.position.x >= 1850.0) {
      terminalReached = true;
      _checkQuestCompletion();
    }

    // Ending scenario trigger: Boss is escaping or has escaped, and player follows to right side (>= 70% of map: 1433.6px)
    if ((boss.hasTriggeredEscape || boss.bossState == BossState.escaping || boss.bossState == BossState.escaped) &&
        !hasTriggeredEscapeScenario) {
      final triggerThresholdX = warehouseWorldWidth * 0.70; // 1433.6 px
      if (player.position.x >= triggerThresholdX) {
        hasTriggeredEscapeScenario = true;
        cutsceneBanner = "EXIT REACHED — PURSUING THE WARLORD!";
        AudioManager.instance.playWebShoot();
        onTriggerEscapeScenario?.call();
      }
    }

    final isSwinging = (player.state == SpideyState.swinging);
    final baseStreetZoom = responsiveStreetZoom(size.y);
    final baseSwingZoom = responsiveSwingZoom(size.y);

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
    final currentZoom = camera.viewfinder.zoom;
    final zoomSpeed = isSwinging ? 2.2 : 1.6;
    final zoomLerp = 1.0 - math.exp(-zoomSpeed * dt);
    camera.viewfinder.zoom = currentZoom + (targetZoom - currentZoom) * zoomLerp;

    // Never zoom out so much that visible height exceeds the warehouse height (eliminates black bands!)
    if (size.y > 0) {
      final minAllowedZoom = size.y / warehouseWorldHeight;
      if (camera.viewfinder.zoom < minAllowedZoom) {
        camera.viewfinder.zoom = minAllowedZoom;
      }
    }

    final targetAnchorY = isSwinging ? 0.72 : 0.85;
    final currentAnchorY = camera.viewfinder.anchor.y;
    final anchorSpeed = isSwinging ? 2.5 : 1.8;
    final anchorLerp = 1.0 - math.exp(-anchorSpeed * dt);
    final newAnchorY = currentAnchorY + (targetAnchorY - currentAnchorY) * anchorLerp;
    camera.viewfinder.anchor = Anchor(0.5, newAnchorY);

    // Camera cutscene glide calculation
    double targetCamX = player.position.x;
    double targetCamY = player.position.y;

    if (cutscenePhase == 1) {
      final t = (_cutsceneTimer / 2.0).clamp(0.0, 1.0);
      final smoothT = (1.0 - math.cos(t * math.pi)) / 2.0;
      targetCamX = player.position.x + (boss.position.x - player.position.x) * smoothT;
      targetCamY = player.position.y + (boss.position.y - player.position.y) * smoothT;
    } else if (cutscenePhase == 2) {
      targetCamX = boss.position.x;
      targetCamY = boss.position.y;
    } else if (cutscenePhase == 3) {
      final t = (_cutsceneTimer / 1.8).clamp(0.0, 1.0);
      final smoothT = (1.0 - math.cos(t * math.pi)) / 2.0;
      targetCamX = boss.position.x + (player.position.x - boss.position.x) * smoothT;
      targetCamY = boss.position.y + (player.position.y - boss.position.y) * smoothT;
    }

    // Camera clamping across warehouse bounds (2048 x 508)
    final zoom = camera.viewfinder.zoom;
    final visibleW = size.x / zoom;
    final visibleH = size.y / zoom;

    if (visibleW < warehouseWorldWidth) {
      final minCamX = visibleW * 0.5;
      final maxCamX = warehouseWorldWidth - (visibleW * 0.5);
      if (minCamX <= maxCamX) {
        targetCamX = targetCamX.clamp(minCamX, maxCamX);
      }
    } else {
      targetCamX = warehouseWorldWidth * 0.5;
    }

    final minCamY = visibleH * newAnchorY;
    final maxCamY = warehouseWorldHeight - (visibleH * (1.0 - newAnchorY));
    if (minCamY <= maxCamY) {
      targetCamY = targetCamY.clamp(minCamY, maxCamY);
    } else {
      targetCamY = minCamY;
    }

    camera.viewfinder.position = Vector2(targetCamX, targetCamY);
  }

  // Keyboard controls
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isEntranceCutscene) {
      return KeyEventResult.handled;
    }
    final isDown = (event is KeyDownEvent || event is KeyRepeatEvent);
    if (isDown) {
      engagePlayer();
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      if (isDown) {
        isLeftPressed = true;
        player.move(-1.0);
      } else {
        isLeftPressed = false;
        player.move(isRightPressed ? 1.0 : 0.0);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      if (isDown) {
        isRightPressed = true;
        player.move(1.0);
      } else {
        isRightPressed = false;
        player.move(isLeftPressed ? -1.0 : 0.0);
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.keyW)) {
      player.jump();
      return KeyEventResult.handled;
    }

    // Punch (18 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyJ ||
            event.logicalKey == LogicalKeyboardKey.keyZ)) {
      player.punch();
      return KeyEventResult.handled;
    }

    // Kick (32 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyK ||
            event.logicalKey == LogicalKeyboardKey.keyX)) {
      player.kick();
      return KeyEventResult.handled;
    }

    // Skill 1 (Web Shot - 35 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyL ||
            event.logicalKey == LogicalKeyboardKey.keyC ||
            event.logicalKey == LogicalKeyboardKey.keyU)) {
      player.useSkill1();
      return KeyEventResult.handled;
    }

    // Web Swing
    if (event.logicalKey == LogicalKeyboardKey.keyE ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (isDown) {
        if (player.state != SpideyState.swinging) {
          shootWebAhead();
        }
      } else if (event is KeyUpEvent) {
        if (player.state == SpideyState.swinging) {
          player.releaseWeb(withBoost: true);
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  WebAnchorPoint? findBestAnchorAhead() {
    WebAnchorPoint? best;
    double minDistance = double.infinity;
    final lookAheadDir = player.isFacingRight ? 1.0 : -1.0;

    for (final a in anchors) {
      final dx = a.position.x - player.position.x;
      final dy = a.position.y - player.position.y;
      if (dy > -60) continue;
      if (dx * lookAheadDir < -20) continue;

      final dist = (a.position - player.position).length;
      if (dist < minDistance && dist <= GameConfig.maxWebDistance) {
        minDistance = dist;
        best = a;
      }
    }
    return best;
  }

  void shootWebAhead() {
    if (isEntranceCutscene) return;
    engagePlayer();
    final anchor = findBestAnchorAhead();
    if (anchor != null) {
      player.shootWeb(anchor.position);
    } else {
      final dir = player.isFacingRight ? 1.0 : -1.0;
      final fallbackAnchor = Vector2(
        player.position.x + dir * 200,
        math.max(100, player.position.y - 240),
      );
      player.shootWeb(fallbackAnchor);
    }
  }

  void shootWebInDirection(Vector2 direction) {
    if (isEntranceCutscene) return;
    engagePlayer();
    if (direction.length < 0.1) return;
    final norm = direction.normalized();
    final targetPos = player.position + norm * GameConfig.maxWebDistance;
    player.shootWeb(targetPos);
  }

  void releaseWeb() {
    if (isEntranceCutscene) return;
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
    }
  }

  void startMoveLeft() {
    if (isEntranceCutscene) return;
    engagePlayer();
    isLeftPressed = true;
    player.move(-1.0);
  }

  void startMoveRight() {
    if (isEntranceCutscene) return;
    engagePlayer();
    isRightPressed = true;
    player.move(1.0);
  }

  void stopMove() {
    isLeftPressed = false;
    isRightPressed = false;
    player.move(0.0);
  }

  void pursueBossToExit() {
    engagePlayer();
    player.isFacingRight = true;
    player.velocity.x = 480.0;
    AudioManager.instance.playWebShoot();
  }

  void punch() {
    if (isEntranceCutscene) return;
    engagePlayer();
    player.punch();
  }

  void kick() {
    if (isEntranceCutscene) return;
    engagePlayer();
    player.kick();
  }

  void jump() {
    if (isEntranceCutscene) return;
    engagePlayer();
    player.jump();
  }

  void useSkill() {
    if (isEntranceCutscene) return;
    engagePlayer();
    player.useSkill1();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isEntranceCutscene) return;
    final worldPoint = camera.globalToLocal(event.localPosition);
    if ((worldPoint - player.position).length < 25) {
      player.punch();
    } else {
      player.shootWeb(worldPoint);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
    }
  }
}
