import 'dart:convert';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/comic_fx.dart';
import 'package:spideyhood/game/components/damage_number.dart';
import 'package:spideyhood/game/story/tech_core.dart';
import 'package:spideyhood/game/story/warehouse_background.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';
import 'package:spideyhood/game/ui/story_intro_screen.dart';

void main() {
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
  });

  group('Story Quest & Warehouse Game Tests', () {
    testWidgets('StoryIntroScreen displays Part 1 slides with per-slide skip button unlocked at half-way (50%)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryIntroScreen(),
        ),
      );

      // Slide 1: Part 1 Scene 1
      expect(find.text('STORY MODE: PART 1 • (1/7)'), findsOneWidget);
      expect(find.textContaining('SCENE 1:'), findsOneWidget);

      // In the first half (e.g. at 1.0s / 25% progress): skip button is LOCKED with countdown
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('SKIP SLIDE ▶'), findsNothing);
      expect(find.textContaining('SKIP IN'), findsOneWidget);

      // Reach half-way mark (at 2.1s / >50% progress): SKIP SLIDE button is unlocked!
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('SKIP SLIDE ▶'), findsOneWidget);

      // Tap skip button: advances ONLY to Scene 2 (per-slide skip)
      await tester.tap(find.text('SKIP SLIDE ▶'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('STORY MODE: PART 1 • (2/7)'), findsOneWidget);
      expect(find.textContaining('SCENE 2:'), findsOneWidget);

      // On Scene 2 start, skip is LOCKED again until 50% of Scene 2 has passed
      expect(find.text('SKIP SLIDE ▶'), findsNothing);
      expect(find.textContaining('SKIP IN'), findsOneWidget);

      // Advance through remaining slides (3 to 7) using half-way skip
      for (int i = 3; i <= 7; i++) {
        await tester.pump(const Duration(milliseconds: 2100));
        expect(find.text('SKIP SLIDE ▶'), findsOneWidget);
        await tester.tap(find.text('SKIP SLIDE ▶'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('STORY MODE: PART 1 • ($i/7)'), findsOneWidget);
      }

      // Final slide skip unlocks and transitions to Warehouse Game
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.text('SKIP SLIDE ▶'), findsOneWidget);
      await tester.tap(find.text('SKIP SLIDE ▶'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(WarehouseGameScreen), findsOneWidget);
    });

    testWidgets('StoryEscapeScreen displays Escape Scenario slides 1 and 2 with half-way skip button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryEscapeScreen(),
        ),
      );

      expect(find.text('STORY MODE: PART 1 • ESCAPE SCENARIO • (1/2)'), findsOneWidget);
      expect(find.textContaining('SCENE 1:'), findsOneWidget);

      // Locked in first 2 seconds
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('SKIP SLIDE ▶'), findsNothing);

      // Unlocks at 50%
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('SKIP SLIDE ▶'), findsOneWidget);

      // Advance to Scene 2
      await tester.tap(find.text('SKIP SLIDE ▶'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('STORY MODE: PART 1 • ESCAPE SCENARIO • (2/2)'), findsOneWidget);
      expect(find.textContaining('SCENE 2:'), findsOneWidget);
    });

    testWidgets('StoryAfterEscapeScreen displays After Escape Scenario slides 1 and 2 with half-way skip button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryAfterEscapeScreen(),
        ),
      );

      expect(find.text('STORY MODE: PART 1 • AFTER ESCAPE SCENARIO • (1/2)'), findsOneWidget);
      expect(find.textContaining('SCENE 1:'), findsOneWidget);

      // Locked in first 2 seconds
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('SKIP SLIDE ▶'), findsNothing);

      // Unlocks at 50%
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('SKIP SLIDE ▶'), findsOneWidget);

      // Advance to Scene 2
      await tester.tap(find.text('SKIP SLIDE ▶'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('STORY MODE: PART 1 • AFTER ESCAPE SCENARIO • (2/2)'), findsOneWidget);
      expect(find.textContaining('SCENE 2:'), findsOneWidget);
    });

    testWidgets('StoryBlackoutScreen displays black screen and advances after duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryBlackoutScreen(
            nextScreen: StoryAfterEscapeScreen(),
            duration: Duration(milliseconds: 1000),
          ),
        ),
      );

      // Initially on blackout screen
      expect(find.byType(StoryBlackoutScreen), findsOneWidget);
      expect(find.byType(StoryAfterEscapeScreen), findsNothing);

      // Advance time by 1000ms + transition
      await tester.pump(const Duration(milliseconds: 1050));
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.byType(StoryAfterEscapeScreen), findsOneWidget);
    });

    test('WarehouseGame cutscene sequence transitions through all camera phases to gameplay', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      expect(game.isEntranceCutscene, isTrue);
      expect(game.cutscenePhase, 0);
      expect(game.player.state, SpideyState.swinging);
      expect(game.player.webAnchor, isNotNull);

      // Phase 0: Spider-Man swinging entrance and landing on floor
      for (int i = 0; i < 70; i++) {
        game.update(0.04);
        game.player.update(0.04);
      }
      expect(game.player.isGrounded, isTrue);
      expect(game.player.position.y, WarehouseGame.warehouseFloorY);
      expect(game.player.state, SpideyState.idle);
      expect(game.cutscenePhase, greaterThanOrEqualTo(1));

      // Phase 1 to Phase 3: Camera pans to boss meeting minions, boss dialogue, and camera pan back
      while (game.isEntranceCutscene) {
        game.update(0.1);
      }

      // Cutscene complete
      expect(game.isEntranceCutscene, isFalse);
      expect(game.cutscenePhase, 4);

      expect(WarehouseBackground.warehouseWidth, 2048.0);
      expect(WarehouseBackground.warehouseHeight, 508.0);
      expect(WarehouseGame.warehouseFloorY, 496.0);
      expect(game.world.children.whereType<WarehouseBackground>(), isNotEmpty);
      expect(game.world.children.whereType<WarehousePlatform>().length, 2);
      expect(game.world.children.whereType<TechCore>().length, 3);
      expect(game.world.children.whereType<ViperGuard>().length, 4);
      expect(game.world.children.whereType<ViperBoss>().length, 1);

      expect(game.player.groundLevel, 496.0);
      expect(game.player.worldWidth, 2048.0);
    });

    test('Minions start lined up on the center catwalk bridge facing the boss and motionless until player gets close or attacks', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.isEntranceCutscene = false;

      final minions = game.world.children.whereType<ViperGuard>().toList();
      expect(minions.length, 4);

      // Verify all 4 minions are positioned on the center catwalk bridge (y = 365)
      for (final minion in minions) {
        expect(minion.position.y, 365.0);
        expect(minion.currentPlatform, isNotNull);
        expect(minion.state, MinionState.idle);
        expect(minion.velocity.x, 0.0);
      }

      // Spidey far away (x = 200, y = 496): minions remain motionless in lineup
      game.player.position = Vector2(200, 496);
      for (int i = 0; i < 10; i++) {
        for (final m in minions) {
          m.update(0.02);
        }
      }
      expect(game.hasPlayerEngaged, isFalse);
      for (final minion in minions) {
        expect(minion.state, MinionState.idle);
        expect(minion.velocity.x, 0.0);
      }

      // Spidey approaches the bridge lineup (within 240px): minions break formation and alert!
      game.player.position = Vector2(750, 350);
      minions.first.update(0.02);
      expect(game.hasPlayerEngaged, isTrue);

      // Now that player engaged, minions start moving / chasing
      for (final m in minions) {
        m.update(0.02);
      }
      expect(minions.first.velocity.x, isNot(0.0));
    });

    test('ViperBoss multi-phase scenario: retreat -> combat -> enrage -> escape -> ending scenario triggered at 70% of map', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.isEntranceCutscene = false;
      game.player.releaseWeb(withBoost: false);
      game.player.position = Vector2(80, 496);
      game.player.velocity.setZero();
      game.player.state = SpideyState.idle;
      game.player.isGrounded = true;

      bool escapeScenarioTriggered = false;
      game.onTriggerEscapeScenario = () {
        escapeScenarioTriggered = true;
      };

      final boss = game.boss;
      expect(boss.bossState, BossState.meetingMinions);
      expect(boss.health, 700);
      expect(boss.maxHealth, 700);

      // 1. When player engages, minions charge and Boss retreats to right side on the ground
      game.engagePlayer();
      expect(game.hasPlayerEngaged, isTrue);
      expect(boss.bossState, BossState.movingToRight);

      // Boss reaches right safe location (x >= 1860) on the floor
      for (int i = 0; i < 60; i++) {
        boss.update(0.1);
      }
      expect(boss.bossState, BossState.waitingRightInvulnerable);
      expect(boss.isInvulnerable, isTrue);
      // Boss stops at x=1860 on the floor of the right terminal sector (y=496)
      expect(boss.position.y, anyOf(equals(356.0), equals(496.0)));

      // 2. Boss cannot receive damage while invulnerable
      boss.takeDamage(50, 1.0);
      expect(boss.health, 700);

      // 3. When initial minions are defeated, Boss summons 5 more and attacks player
      final initialMinions = game.world.children.whereType<ViperGuard>().toList();
      for (final minion in initialMinions) {
        minion.removeFromParent();
      }
      game.checkAllMinionsDefeated();
      expect(boss.bossState, BossState.summoningPhase1);

      // Update boss during summon sequence
      boss.update(1.6);
      expect(boss.bossState, BossState.combat);
      expect(boss.isInvulnerable, isFalse);

      // 4. Damage Boss to 50% HP (<= 350 HP remaining, 25% passive armor) -> Enraged state
      boss.takeDamage(467, -1.0); // 467 * 0.75 = 350 damage dealt -> 350 HP (50%)
      expect(boss.health, lessThanOrEqualTo(350));
      expect(boss.bossState, BossState.enragedCombat);
      expect(boss.isEnraged, isTrue);
      expect(boss.currentAnim, BossAnimPose.skill);
      expect(boss.attackDamage, 36);

      // 5. Damage Boss to <= 10% HP (<= 70 HP, 65% enraged armor) -> Boss escapes
      boss.update(0.25);
      boss.takeDamage(850, -1.0); // 850 * 0.35 = 298 dmg -> 52 HP (<= 10%)
      expect(boss.health, lessThanOrEqualTo(70));
      expect(boss.bossState, BossState.escaping);
      expect(boss.hasTriggeredEscape, isTrue);

      // 6. Verify Ending Scenario is NOT triggered while player is below 70% of the map (x < 1433.6)
      game.player.position = Vector2(800, 496);
      game.update(0.05);
      expect(escapeScenarioTriggered, isFalse);
      expect(game.hasTriggeredEscapeScenario, isFalse);

      // 7. Verify Ending Scenario is NOT triggered even at 70% if summoned minions are still alive
      game.player.position = Vector2(1450, 496);
      game.update(0.05);
      expect(escapeScenarioTriggered, isFalse);
      expect(game.hasTriggeredEscapeScenario, isFalse);

      // 8. Player defeats all remaining minions summoned by the boss
      final escapeMinions = game.world.children.whereType<ViperGuard>().toList();
      for (final m in escapeMinions) {
        m.removeFromParent();
      }
      // Clear the pending flag (microtask normally fires between frames; flush it here)
      game.boss.escapeMinionsPending = false;

      // Now with all minions defeated, crossing 70% threshold triggers Ending Scenario!
      game.player.position = Vector2(1450, 496);
      game.update(0.05);
      expect(escapeScenarioTriggered, isTrue);
      expect(game.hasTriggeredEscapeScenario, isTrue);
    });

    test('TechCore and ViperGuard update without throwing and display DamageNumber without ComicFx', () async {
      final core = TechCore(position: Vector2(200, 200), coreId: 1);
      await core.onLoad();
      core.update(0.1);
      expect(core.isCollected, isFalse);

      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final guard = game.world.children.whereType<ViperGuard>().first;
      expect(guard.health, 126); // 126 HP = 7 punches of 18 dmg
      expect(guard.isDefeated, isFalse);

      // Attack minion and verify DamageNumber is spawned instead of ComicFx
      guard.takeDamage(18, 1.0);
      expect(guard.health, 108);
      expect(game.world.children.whereType<DamageNumber>(), isNotEmpty);
      expect(game.world.children.whereType<ComicFx>(), isEmpty);

      // Web shot hits minion: deals 2 damage and slows
      guard.update(0.3);
      guard.hitByWeb(1.0);
      expect(guard.health, 106);
    });

    test('WarehousePlatform maintains solid grounded footing at y = 320 and y = 365 without floating', () async {
      // Left platform (y = 320)
      final leftPlatform = WarehousePlatform(position: Vector2(10, 320), size: Vector2(360, 20));
      final guard = ViperGuard(position: Vector2(100, 320), groundLevel: 496.0);
      guard.onCollision({Vector2(100, 320)}, leftPlatform);

      expect(guard.isGrounded, isTrue);
      expect(guard.currentPlatform, equals(leftPlatform));
      expect(guard.position.y, equals(320.0));

      // Update frame on platform
      guard.update(0.016);
      expect(guard.isGrounded, isTrue);
      expect(guard.position.y, equals(320.0));

      // Spidey on center platform (y = 365)
      final centerPlatform = WarehousePlatform(position: Vector2(610, 365), size: Vector2(680, 20));
      final spidey = Spidey(position: Vector2(700, 365), groundLevel: 496.0);
      spidey.onCollision({Vector2(700, 365)}, centerPlatform);
      expect(spidey.isGrounded, isTrue);
      expect(spidey.currentPlatform, equals(centerPlatform));
      expect(spidey.position.y, equals(365.0));

      spidey.update(0.016);
      expect(spidey.isGrounded, isTrue);
      expect(spidey.position.y, equals(365.0));
    });

    test('Minion leaps across platform gap and up to platform from floor', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.isEntranceCutscene = false;
      game.hasPlayerEngaged = true;

      // Minion near left platform edge (x=330, y=320) chasing player on center bridge (x=700, y=365)
      final leftPlatform = game.world.children.whereType<WarehousePlatform>().first;
      final guard = ViperGuard(position: Vector2(330, 320), groundLevel: 496.0);
      game.world.add(guard);
      guard.currentPlatform = leftPlatform;
      guard.isGrounded = true;
      guard.patrolDirection = 1.0;
      game.player.position = Vector2(700, 365);

      guard.update(0.02);
      // Guard should execute gap leap across 260px void (-520 initial + 1400*0.02 gravity)
      expect(guard.velocity.y, closeTo(-492.0, 0.5));
      expect(guard.velocity.x, equals(360.0));
      expect(guard.isGrounded, isFalse);

      // Minion on floor (x=200, y=496) chasing player on left platform (x=200, y=320)
      final floorGuard = ViperGuard(position: Vector2(200, 496), groundLevel: 496.0);
      game.world.add(floorGuard);
      game.update(0.001);
      game.player.position = Vector2(200, 320);

      floorGuard.update(0.02);
      // Guard leaps up to reach elevated left platform (-700 initial + 1400*dt gravity)
      expect(floorGuard.velocity.y, closeTo(-672.0, 2.0));
      expect(floorGuard.isGrounded, isFalse);
    });

    test('Spidey punch and kick successfully damage minion at close and point-blank range', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.isEntranceCutscene = false;
      game.hasPlayerEngaged = true;

      final guard = game.world.children.whereType<ViperGuard>().first;
      guard.health = 126;
      // Position Spidey close to minion
      game.player.position = guard.position.clone() - Vector2(20, 0);
      game.player.isFacingRight = true;

      game.player.punch();
      expect(guard.health, 108); // 126 - 18 = 108
    });

    test('ViperBoss can still attack even while taking damage (uninterrupted poise)', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      game.isEntranceCutscene = false;
      game.hasPlayerEngaged = true;

      final boss = game.world.children.whereType<ViperBoss>().first;
      boss.bossState = BossState.combat;
      game.player.position = Vector2(500, 496);
      boss.position = Vector2(520, 496);
      game.player.health = 100;

      // Advance past initial attack cooldown so boss is primed to attack
      boss.update(1.0);

      // Spidey damages the boss
      boss.takeDamage(24, 1.0);
      expect(boss.health, lessThan(boss.maxHealth));

      // Boss updates frame: despite taking damage, boss initiates punch or kick!
      boss.update(0.016);
      expect(
        boss.animPose == BossAnimPose.punching || boss.animPose == BossAnimPose.kicking,
        isTrue,
      );
      expect(game.player.health, lessThan(100));

      // While boss is in the middle of attacking, boss takes damage again
      boss.takeDamage(20, 1.0);
      // Hyper-armor ensures attack animation is NOT interrupted into hurt flinch
      expect(
        boss.animPose == BossAnimPose.punching || boss.animPose == BossAnimPose.kicking,
        isTrue,
      );
    });
  });
}
