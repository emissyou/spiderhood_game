import 'dart:convert';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spideyhood/game/actors/enemies/minion_with_gun.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/components/gun_bullet.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/moonlit_rooftop_game.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/moonlit_loading_screen.dart';
import 'package:spideyhood/game/ui/moonlit_rooftop_hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final Uint8List mockPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        return ByteData.view(mockPng.buffer);
      },
    );
    AudioManager.instance.isMuted = true;
  });

  group('Moonlit Rooftop Cityscape Tests', () {
    test('MoonlitRooftopGame initializes with 7 building platforms and spawns hero on first platform', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Verify building platforms
      expect(game.platforms.length, equals(7));

      // Building 1 (first platform)
      expect(game.platforms[0].position.x, equals(0.0));
      expect(game.platforms[0].position.y, equals(414.0));
      expect(game.platforms[0].size.x, equals(192.0));
      expect(game.platforms[0].size.y, equals(724.0 - 414.0));

      // Building 2
      expect(game.platforms[1].position.x, equals(323.0));
      expect(game.platforms[1].position.y, equals(536.0));
      expect(game.platforms[1].size.x, equals(209.0));
      expect(game.platforms[1].size.y, equals(724.0 - 536.0));

      // Building 3 (main & ledge)
      expect(game.platforms[2].position.x, equals(675.0));
      expect(game.platforms[2].position.y, equals(460.0));
      expect(game.platforms[2].size.x, equals(215.0));
      expect(game.platforms[2].size.y, equals(724.0 - 460.0));
      expect(game.platforms[3].position.x, equals(888.0));
      expect(game.platforms[3].position.y, equals(549.0));
      expect(game.platforms[3].size.y, equals(724.0 - 549.0));

      // Building 4
      expect(game.platforms[4].position.x, equals(1212.0));
      expect(game.platforms[4].position.y, equals(491.0));
      expect(game.platforms[4].size.x, equals(239.0));
      expect(game.platforms[4].size.y, equals(724.0 - 491.0));

      // Building 5
      expect(game.platforms[5].position.x, equals(1641.0));
      expect(game.platforms[5].position.y, equals(500.0));
      expect(game.platforms[5].size.x, equals(212.0));
      expect(game.platforms[5].size.y, equals(724.0 - 500.0));

      // Building 6 (far right)
      expect(game.platforms[6].position.x, equals(1987.0));
      expect(game.platforms[6].position.y, equals(472.0));
      expect(game.platforms[6].size.x, equals(185.0));
      expect(game.platforms[6].size.y, equals(724.0 - 472.0));

      // Verify Hero Spawns directly on first platform with 3 hearts max
      expect(game.player.position.x, equals(80.0));
      expect(game.player.position.y, equals(414.0));
      expect(game.player.health, equals(3));
      expect(game.player.effectiveMaxHealth, equals(3));
      expect(game.player.allowHealthRegen, isFalse);
      expect(game.player.isGrounded, isTrue);
      expect(game.player.currentPlatform, equals(game.platforms[0]));
      expect(game.player.swingCooldownMax, equals(1.8));
      expect(game.player.swingReleaseFactor, equals(0.45));
      expect(game.player.maxSwingDuration, equals(1.0));
      expect(game.player.maxWebDistanceOverride, equals(110.0));
      expect(game.player.skillShotHeightOffset, equals(14.0));
    });

    test('Player can jump, move and web swing across rooftops', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Running right
      game.onRightDown();
      game.update(0.1);
      expect(game.player.velocity.x, greaterThan(0));
      game.onRightUp();

      // Jump
      game.onJumpPress();
      expect(game.player.velocity.y, lessThan(0));

      // Web swing
      game.onSwingDown();
      expect(game.player.webAnchor, isNotNull);
      game.onSwingUp();
      expect(game.player.webAnchor, isNull);
    });

    testWidgets('MoonlitLoadingScreen renders map title and progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoonlitLoadingScreen(),
        ),
      );

      expect(find.text('STORY MODE • CHAPTER 2'), findsOneWidget);
      expect(find.textContaining('MOONLIT ROOFTOP'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MoonlitLoadingScreen), findsOneWidget);
    });

    testWidgets('MoonlitRooftopHud renders controls and status info', (tester) async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoonlitRooftopHud(game: game),
          ),
        ),
      );

      expect(find.text('MOONLIT ROOFTOP CITYSCAPE'), findsOneWidget);
      expect(find.text('SWING'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);
      expect(find.text('DOWN'), findsOneWidget);
      expect(find.text('PUNCH'), findsOneWidget);
      expect(find.text('KICK'), findsOneWidget);
      expect(find.text('SKILL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    test('MinionWithGun stays in idle without walking, wakes up when player moves, and aims at player', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Verify MinionWithGun is mounted on Building 6 (far right building)
      final gunMinion = game.gunMinion;
      expect(gunMinion, isNotNull);
      expect(gunMinion.position.x, equals(2080.0));
      expect(gunMinion.position.y, equals(492.0));
      expect(gunMinion.currentPlatform, equals(game.platforms[6]));
      expect(gunMinion.state, equals(GunMinionState.idle));

      // Minion stays stationary (does not walk/patrol) while player is idle at spawn
      final initialMinionX = gunMinion.position.x;
      game.update(0.5);
      expect(gunMinion.position.x, equals(initialMinionX));
      expect(gunMinion.state, equals(GunMinionState.idle));

      // When player moves, marksman awakens and initiates shooting sequence
      game.onRightDown();
      game.update(0.1);
      game.onRightUp();
      expect(gunMinion.hasPlayerMoved, isTrue);

      // Verify Gun barrel height alignment (rifle level ~66% above feet)
      final barrelPos = gunMinion.gunBarrelPosition;
      final expectedY = 492.0 - (gunMinion.size.y * (89.0 / 135.0));
      expect(barrelPos.y, closeTo(expectedY, 0.5));
      // Minion faces left towards oncoming player initially
      expect(gunMinion.isFacingRight, isFalse);
      expect(barrelPos.x, lessThan(gunMinion.position.x));

      // When guards are alive, minion is shielded and deflects damage
      expect(gunMinion.isShielded, isTrue);
      gunMinion.takeDamage(18);
      expect(gunMinion.health, equals(MinionWithGun.maxHp));

      // Defeating all guards drops the shield
      for (final guard in game.world.children.whereType<ViperGuard>().toList()) {
        guard.takeDamage(200, 1.0);
      }
      expect(gunMinion.isShielded, isFalse);

      // Spidey attacks now damage minion
      gunMinion.takeDamage(18);
      expect(gunMinion.health, equals(MinionWithGun.maxHp - 18));
      expect(gunMinion.state, equals(GunMinionState.hurt));
    });

    test('Spidey dropDownPlatform descends through platform surface', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      expect(game.player.currentPlatform, equals(game.platforms[0]));
      expect(game.player.isGrounded, isTrue);

      game.dropDownPlatform();

      expect(game.player.currentPlatform, isNull);
      expect(game.player.isGrounded, isFalse);
      expect(game.player.ignorePlatformLanding, isTrue);
      expect(game.player.velocity.y, greaterThan(0));
    });

    test('GunBullet moves horizontally, hits Spidey, and inflicts damage', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.player.isGodMode = false;

      final initialHp = game.player.health;
      final bullet = GunBullet(
        position: Vector2(game.player.position.x + 20.0, game.player.position.y - 20.0),
        direction: -1.0,
        speed: 500.0,
      );
      game.world.add(bullet);
      await game.ready();

      // Advance game to trigger collision
      game.update(0.1);

      expect(game.player.health, lessThan(initialHp));
      // Moderate stagger knockback (not fling too far)
      expect(game.player.velocity.x, equals(-85.0));
      expect(game.player.velocity.y, equals(-50.0));
    });

    test('Moonlit Rooftop map has wide zoomed-out viewport settings', () {
      // 420.0 visible height enables wider viewing area of the moonlit skyline
      expect(MoonlitRooftopGame.targetVisibleHeight, equals(420.0));
      expect(MoonlitRooftopGame.targetSwingVisibleHeight, equals(520.0));

      final streetZoom = MoonlitRooftopGame.responsiveStreetZoom(600);
      expect(streetZoom, closeTo(600 / 420.0, 0.01));
    });

    test('StoryProgressService correctly saves checkpoint and allows restarting story or part', () async {
      final story = StoryProgressService.instance;
      await story.resetStory();
      expect(story.currentPart, equals(1));
      expect(story.currentPartTitle, contains('PART 1'));

      await story.completePart1();
      expect(story.currentPart, equals(2));
      expect(story.currentPartTitle, contains('PART 2'));

      // Player can restart part
      await story.setPart(2);
      expect(story.currentPart, equals(2));

      // Player can restart story
      await story.resetStory();
      expect(story.currentPart, equals(1));
    });

    testWidgets('ModeSelectScreen displays continue Part 2 checkpoint and story options', (tester) async {
      final story = StoryProgressService.instance;
      await story.completePart1();

      await tester.pumpWidget(
        const MaterialApp(
          home: ModeSelectScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CONTINUE (PART 2) ▶'), findsOneWidget);
      expect(find.text('CHOOSE PART (1, 2, OR 3) ❖'), findsOneWidget);
      expect(find.text('PART 1 ▶'), findsOneWidget);
      expect(find.text('PART 2 ▶'), findsOneWidget);
      expect(find.text('PART 3 ▶'), findsOneWidget);
      expect(find.text('RESTART STORY ↺'), findsOneWidget);
      expect(find.text('PART 2: ROOFTOPS'), findsOneWidget);
      expect(find.textContaining('Moonlit Rooftop Cityscape'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await story.resetStory();
    });

    test('Part 2 mission requires defeating all 4 enemies (3 guards + 1 gun minion) to complete', () async {
      final game = MoonlitRooftopGame();
      bool completed = false;
      game.onMissionComplete = () {
        completed = true;
      };
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      expect(game.totalEnemies, equals(4));
      expect(game.defeatedEnemies, equals(0));

      final guards = game.world.children.whereType<ViperGuard>().toList();
      expect(guards.length, equals(3));

      // Attempting to damage gun minion while guards are alive fails (shielded)
      expect(game.gunMinion.isShielded, isTrue);
      game.gunMinion.takeDamage(200);
      expect(game.defeatedEnemies, equals(0));

      // Defeat first 2 guards
      guards[0].takeDamage(200, 1.0);
      guards[1].takeDamage(200, 1.0);
      expect(game.defeatedEnemies, equals(2));
      expect(completed, isFalse);

      // Defeat the final remaining guard
      guards[2].takeDamage(200, 1.0);
      expect(game.defeatedEnemies, equals(3));
      expect(completed, isFalse);

      // Shield is now deactivated on the gun minion
      expect(game.gunMinion.isShielded, isFalse);

      // Defeat gun minion
      game.gunMinion.takeDamage(200);
      expect(game.defeatedEnemies, equals(4));
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(completed, isTrue);
    });

    test('Spidey cannot pass horizontally through solid building bodies below rooftop level', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Place Spidey in the alley gap between Building 1 (ends at x=192, y=414) and Building 2 (starts at x=316, y=536)
      // Position Spidey below Building 1 rooftop: x = 205, y = 500
      game.player.position = Vector2(205.0, 500.0);
      game.player.velocity = Vector2(-300.0, 0.0); // Moving left into Building 1's solid wall

      game.update(0.05);

      // Player must be blocked by the solid wall of Building 1 and cannot penetrate x <= 192.0
      expect(game.player.position.x, greaterThanOrEqualTo(192.0 - 0.1));
    });

    test('Spidey web swing automatically releases after 1.0 second hold limit', () async {
      final game = MoonlitRooftopGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      game.onSwingDown();
      expect(game.player.webAnchor, isNotNull);

      // Advance by 0.5s - still swinging
      game.update(0.5);
      expect(game.player.webAnchor, isNotNull);

      // Advance past 1.0s total - auto-cuts swing!
      game.update(0.55);
      expect(game.player.webAnchor, isNull);
    });

    test('Enemy falling off rooftop platform dies fatally when hitting alley floor', () async {
      final game = MoonlitRooftopGame();
      int defeatedCount = 0;
      final guard = ViperGuard(
        position: Vector2(350, 500),
        groundLevel: 724.0,
        onDefeated: () {
          defeatedCount++;
        },
      );
      game.world.add(guard);
      await game.ready();

      // Guard falls into alley pit
      guard.position.y = 724.0;
      guard.update(0.016);

      expect(guard.isDefeated, isTrue);
      expect(defeatedCount, equals(1));
    });
  });
}
