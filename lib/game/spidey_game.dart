import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:spideyhood/game/actors/civilian.dart';
import 'package:spideyhood/game/actors/enemies/thug.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/ground.dart';
import 'package:spideyhood/game/components/ny_background.dart';
import 'package:spideyhood/game/components/taxi.dart';
import 'package:spideyhood/game/components/web_anchor_point.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/services/audio_manager.dart';

class SpideyGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapCallbacks {
  late final Spidey player;
  final List<WebAnchorPoint> anchors = [];

  // Callback to return to level selection menu
  VoidCallback? onExitToMenu;

  // Track key states for smooth movement
  bool isLeftPressed = false;
  bool isRightPressed = false;

  // Progressive camera zoom tracking
  double _currentSwingZoomTarget = GameConfig.streetZoom;
  bool _wasSwingingLastFrame = false;

  @override
  Color backgroundColor() => const Color(0xFF1E2235);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Ensure background music is actively playing in the game session
    if (!AudioManager.instance.isMuted && !AudioManager.instance.isPlaying) {
      AudioManager.instance.playBgm();
    }

    // 1. Add Custom New York Morning Background (exact 2086 x 754 bounds)
    world.add(NyBackground());

    // 2. Flat ground baseline matching sidewalk pavement (car road below is excluded)
    world.add(Ground());

    // 3. Spawn Spidey character standing firmly on the sidewalk
    player = Spidey(position: Vector2(500, GameConfig.groundY));
    world.add(player);

    // Spawn neighborhood thugs along the sidewalk
    world.add(Thug(position: Vector2(950, GameConfig.groundY), patrolRange: 160));
    world.add(Thug(position: Vector2(1550, GameConfig.groundY), patrolRange: 180));

    // Lightweight ambient: 2 civilians along the sidewalk
    world.add(Civilian(position: Vector2(320.0, GameConfig.groundY), variant: 1, direction: 1.0, speed: 38.0));
    world.add(Civilian(position: Vector2(1380.0, GameConfig.groundY), variant: 2, direction: -1.0, speed: 40.0));

    // Lightweight ambient: 1 yellow taxi driving along the road lane
    world.add(Taxi(position: Vector2(200.0, 750.0), taxiIndex: 1, baseSpeed: 160.0, direction: 1.0));

    // 4. Building web anchors along building ledges & rooftops
    final buildingAnchorPoints = [
      Vector2(140, 310),
      Vector2(300, 260),
      Vector2(480, 330),
      Vector2(660, 250),
      Vector2(840, 300),
      Vector2(1020, 270),
      Vector2(1200, 330),
      Vector2(1380, 250),
      Vector2(1560, 290),
      Vector2(1740, 330),
      Vector2(1920, 270),
    ];
    for (final pt in buildingAnchorPoints) {
      final anchor = WebAnchorPoint(position: pt);
      anchors.add(anchor);
      world.add(anchor);
    }

    // 5. Camera framing:
    // Street view frames Spidey on sidewalk and shows the street traffic lane below
    final initialZoom = GameConfig.responsiveStreetZoom(size.y);
    _currentSwingZoomTarget = initialZoom;
    camera.viewfinder.anchor = const Anchor(0.5, 0.91);
    camera.viewfinder.zoom = initialZoom;
    camera.viewfinder.position = Vector2(player.position.x, player.position.y);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final baseZoom = GameConfig.responsiveStreetZoom(size.y);
      if (player.state != SpideyState.swinging) {
        camera.viewfinder.zoom = baseZoom;
        _currentSwingZoomTarget = baseZoom;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final isSwinging = (player.state == SpideyState.swinging);
    final baseStreetZoom = GameConfig.responsiveStreetZoom(size.y);
    final baseSwingZoom = GameConfig.responsiveSwingZoom(size.y);

    // Zoom out ONLY when actively web-swinging. Normal jumping stays at normal street zoom.
    if (isSwinging) {
      if (!_wasSwingingLastFrame) {
        _currentSwingZoomTarget = camera.viewfinder.zoom;
      }
      _currentSwingZoomTarget = math.max(
        baseSwingZoom,
        _currentSwingZoomTarget - (dt * 1.15),
      );
    } else {
      // When not web-swinging (jumping, running, standing), smoothly return to normal street view
      _currentSwingZoomTarget = baseStreetZoom;
    }
    _wasSwingingLastFrame = isSwinging;

    final targetZoom = _currentSwingZoomTarget;
    final currentZoom = camera.viewfinder.zoom;

    // Responsive smooth zoom during swing, and calm steady return when not swinging
    final zoomSpeed = isSwinging ? 2.2 : 1.6;
    final zoomLerp = 1.0 - math.exp(-zoomSpeed * dt);
    camera.viewfinder.zoom = currentZoom + (targetZoom - currentZoom) * zoomLerp;

    // Dynamic vertical anchor:
    // Headroom (0.72) only during web-swinging, otherwise street level framing (0.91)
    final targetAnchorY = isSwinging ? 0.72 : 0.91;
    final currentAnchorY = camera.viewfinder.anchor.y;
    final anchorSpeed = isSwinging ? 2.5 : 1.8;
    final anchorLerp = 1.0 - math.exp(-anchorSpeed * dt);
    final newAnchorY = currentAnchorY + (targetAnchorY - currentAnchorY) * anchorLerp;
    camera.viewfinder.anchor = Anchor(0.5, newAnchorY);

    // Edge-clamped camera tracking:
    // Camera follows Spidey directly, smoothly centering on character
    final zoom = camera.viewfinder.zoom;
    final visibleW = size.x / zoom;
    final visibleH = size.y / zoom;

    // Horizontal tracking with boundary limits
    double targetCamX = player.position.x;
    if (visibleW < GameConfig.bgWidth) {
      final minCamX = visibleW * 0.5;
      final maxCamX = GameConfig.bgWidth - (visibleW * 0.5);
      if (minCamX <= maxCamX) {
        targetCamX = targetCamX.clamp(minCamX, maxCamX);
      }
    }

    // Vertical tracking with sidewalk and street visibility
    double targetCamY = player.position.y;
    final maxBottomCutoffY = GameConfig.bgHeight;
    if (visibleH < maxBottomCutoffY) {
      final minCamY = visibleH * newAnchorY;
      final maxCamY = maxBottomCutoffY - (visibleH * (1.0 - newAnchorY));
      if (minCamY <= maxCamY) {
        targetCamY = targetCamY.clamp(minCamY, maxCamY);
      }
    }

    // Assigning to viewfinder.position triggers the Transform2D setter to recalculate matrix
    camera.viewfinder.position = Vector2(targetCamX, targetCamY);
  }

  /// Locate the nearest valid building anchor ahead of Spidey
  WebAnchorPoint? findBestAnchorAhead() {
    WebAnchorPoint? best;
    double minDistance = double.infinity;

    for (final anchor in anchors) {
      final dist = (anchor.position - player.position).length;
      final isAhead = player.isFacingRight
          ? anchor.position.x > player.position.x - 40
          : anchor.position.x < player.position.x + 40;

      if (dist <= GameConfig.maxWebDistance &&
          anchor.position.y < player.position.y &&
          isAhead &&
          dist < minDistance) {
        minDistance = dist;
        best = anchor;
      }
    }
    return best;
  }

  /// Shoot web ahead in facing direction
  void shootWebAhead() {
    final bestAnchor = findBestAnchorAhead();
    if (bestAnchor != null) {
      player.shootWeb(bestAnchor.position);
    } else {
      final forwardX = player.isFacingRight ? 260.0 : -260.0;
      final targetPoint = player.position + Vector2(forwardX, -340.0);
      player.shootWeb(targetPoint);
    }
  }

  /// Shoot web in a dragged aim direction
  void shootWebInDirection(Vector2 direction) {
    final targetPoint = player.position + (direction.normalized() * (GameConfig.maxWebDistance * 0.75));
    player.shootWeb(targetPoint);
  }

  /// Release web with jump boost
  void releaseWeb() {
    if (player.state == SpideyState.swinging) {
      player.releaseWeb(withBoost: true);
    }
  }

  // Mobile / UI overlay controls hooks
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
  void punch() => player.punch();
  void kick() => player.kick();
  void useSkill() => player.useSkill1();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;

    // Movement Left
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

    // Movement Right
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

    // Jump / Leap / Crawl release
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.keyW)) {
      player.jump();
      return KeyEventResult.handled;
    }

    // Punch Attack (18 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyJ ||
            event.logicalKey == LogicalKeyboardKey.keyZ)) {
      player.punch();
      return KeyEventResult.handled;
    }

    // Kick Attack (32 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyK ||
            event.logicalKey == LogicalKeyboardKey.keyX)) {
      player.kick();
      return KeyEventResult.handled;
    }

    // Skill 1 (Web Shot Ammo Blast - 35 Damage)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyL ||
            event.logicalKey == LogicalKeyboardKey.keyC ||
            event.logicalKey == LogicalKeyboardKey.keyU)) {
      player.useSkill1();
      return KeyEventResult.handled;
    }

    // Shoot Web Swing: hold key to swing, release key to release web!
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

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final worldPoint = camera.globalToLocal(event.localPosition);

    // If clicked near character body: punch!
    if ((worldPoint - player.position).length < 25) {
      player.punch();
    } else {
      // Clicked anywhere on screen: shoot web to that exact spot and HOLD!
      player.shootWeb(worldPoint);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    // When mouse click is released: release web with swing leap!
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
