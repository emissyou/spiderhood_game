import 'dart:convert';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/components/pickup_drop.dart';
import 'package:spideyhood/game/components/web_ammo.dart';
import 'package:spideyhood/game/components/web_mark.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/story/warehouse_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GameConfig.godMode = false;
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

  group('Player Mechanics (5 Hearts, Web Fluid, 3s Cooldown, Shield)', () {
    test('Spidey has 5 hearts max health, takes 1 heart damage per hit with invulnerability frames', () {
      final spidey = Spidey(position: Vector2(100, 496));
      expect(spidey.health, equals(5));
      expect(Spidey.maxHealth, equals(5));

      // 1st hit -> 4 hearts
      spidey.takeDamage(18);
      expect(spidey.health, equals(4));

      // Immediate 2nd hit during invulnerability frames is blocked
      spidey.takeDamage(18);
      expect(spidey.health, equals(4));

      // After invulnerability cooldown expires (0.8s)
      spidey.update(0.85);
      spidey.takeDamage(18);
      expect(spidey.health, equals(3));
    });

    test('Web fluid has max 10 swings, consumes 1 per swing, and regenerates slower (0.75/s)', () {
      final spidey = Spidey(position: Vector2(100, 496));
      expect(spidey.webFluid, equals(10.0));
      expect(Spidey.maxWebFluid, equals(10));

      // 1 swing consumes 1 web fluid
      spidey.shootWeb(Vector2(100, 100));
      expect(spidey.webFluid, equals(9.0));

      // Deplete all 9 remaining swings
      for (int i = 0; i < 9; i++) {
        spidey.shootWeb(Vector2(100, 100));
      }
      expect(spidey.webFluid, equals(0.0));

      // Cannot swing with 0 web fluid
      spidey.releaseWeb();
      spidey.shootWeb(Vector2(100, 100));
      expect(spidey.webAnchor, isNull);

      // Regenerates steadily over time (0.75 units / sec)
      spidey.update(2.0);
      expect(spidey.webFluid, greaterThanOrEqualTo(1.4));
      expect(spidey.webFluid, lessThanOrEqualTo(10.0));
    });

    test('Skill 1 has 3 seconds cooldown and cannot be re-cast while active or cooling down', () {
      final spidey = Spidey(position: Vector2(100, 496));
      expect(spidey.skill1Cooldown, equals(0.0));

      // Cast Skill 1
      spidey.useSkill1();
      expect(spidey.state, equals(SpideyState.skill1));
      expect(spidey.skill1Cooldown, equals(3.0));

      // Cannot cast again immediately while on cooldown
      spidey.state = SpideyState.idle;
      spidey.useSkill1();
      expect(spidey.state, equals(SpideyState.idle));

      // Advance 2.0s: still 1.0s remaining on cooldown
      spidey.update(2.0);
      expect(spidey.skill1Cooldown, closeTo(1.0, 0.05));
      spidey.useSkill1();
      expect(spidey.state, equals(SpideyState.idle));

      // Advance remaining 1.1s: cooldown expires
      spidey.update(1.1);
      expect(spidey.skill1Cooldown, equals(0.0));
      spidey.useSkill1();
      expect(spidey.state, equals(SpideyState.skill1));
    });

    test('Godmode makes Spidey immortal with infinite web fluid and 0 skill cooldown', () {
      final spidey = Spidey(position: Vector2(100, 496), isGodMode: true);
      expect(spidey.activeGodMode, isTrue);

      // Takes no damage from any hit
      spidey.takeDamage(50);
      expect(spidey.health, equals(Spidey.maxHealth));
      spidey.takeDamage(100);
      expect(spidey.health, equals(Spidey.maxHealth));

      // Web fluid never depletes
      spidey.shootWeb(Vector2(200, 300));
      expect(spidey.webFluid, equals(Spidey.maxWebFluid));

      // Skill 1 has 0 cooldown
      spidey.state = SpideyState.idle;
      spidey.useSkill1();
      expect(spidey.skill1Cooldown, equals(0.0));
    });

    test('Shield drop gives 1 second invulnerability, blocking damage', () {
      final spidey = Spidey(position: Vector2(100, 496));
      expect(spidey.shieldTimer, equals(0.0));

      // Activate shield (lasts exactly 1 second)
      spidey.shieldTimer = 1.0;
      spidey.takeDamage(36);
      expect(spidey.health, equals(5)); // No health lost!

      // After 0.5s: still protected
      spidey.update(0.5);
      spidey.takeDamage(36);
      expect(spidey.health, equals(5));

      // After 0.6s (total 1.1s): shield expired
      spidey.update(0.6);
      expect(spidey.shieldTimer, equals(0.0));
      spidey.takeDamage(18);
      expect(spidey.health, equals(4)); // Now takes damage
    });

    test('Spidey attacks deal damage one at a time to closest enemy', () async {
      final game = FlameGame();
      final spidey = Spidey(position: Vector2(100, 496));
      final guard1 = ViperGuard(position: Vector2(120, 496)); // Closest
      final guard2 = ViperGuard(position: Vector2(135, 496)); // Further

      await game.add(spidey);
      await game.add(guard1);
      await game.add(guard2);
      await game.ready();

      final initialHp1 = guard1.health;
      final initialHp2 = guard2.health;

      // Spidey attacks
      spidey.punch();
      spidey.update(0.016);

      // Only the closest enemy (guard1) should take damage, not guard2
      expect(guard1.health, lessThan(initialHp1));
      expect(guard2.health, equals(initialHp2));
    });
  });

  group('WebAmmo & WebMark Effects', () {
    test('WebAmmo impact creates WebMark (same as after swing)', () async {
      final game = FlameGame();
      final ammo = WebAmmo(position: Vector2(100, 100), direction: 1.0);
      final guard = ViperGuard(position: Vector2(108, 100));
      await game.add(guard);
      await game.add(ammo);
      await game.ready();

      // Ammo overlaps and hits guard
      ammo.update(0.016);
      final marks = game.children.whereType<WebMark>().toList();
      expect(marks, isNotEmpty);
    });
  });

  group('Supply Drops (Heal, Web Fluid, Shield, Compound-V)', () {
    test('PickupDrop applies heal to player when collected', () async {
      final spidey = Spidey(position: Vector2(100, 496));
      spidey.health = 3;

      final drop = PickupDrop(position: Vector2(100, 496), type: DropType.heal);
      drop.onCollision({Vector2(100, 496)}, spidey);

      expect(spidey.health, equals(4));
    });

    test('PickupDrop applies web fluid to player when collected', () async {
      final spidey = Spidey(position: Vector2(100, 496));
      spidey.webFluid = 2.0;

      final drop = PickupDrop(position: Vector2(100, 496), type: DropType.webFluid);
      drop.onCollision({Vector2(100, 496)}, spidey);

      expect(spidey.webFluid, equals(7.0));
    });

    test('PickupDrop applies 1-second shield to player when collected', () async {
      final spidey = Spidey(position: Vector2(100, 496));
      expect(spidey.shieldTimer, equals(0.0));

      final drop = PickupDrop(position: Vector2(100, 496), type: DropType.shield);
      drop.onCollision({Vector2(100, 496)}, spidey);

      expect(spidey.shieldTimer, equals(1.0));
    });

    test('Random platform supply drops spawn on platforms and respect limit of max 3', () async {
      final game = WarehouseGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Check initial platform drops
      final initialDrops = game.world.children.whereType<PickupDrop>().toList();
      expect(initialDrops.length, inInclusiveRange(1, WarehouseGame.maxActiveDrops));

      // Advance time for periodic spawning
      for (int i = 0; i < 300; i++) {
        game.update(0.05);
      }

      final activeDrops = game.world.children.whereType<PickupDrop>().toList();
      expect(activeDrops.length, lessThanOrEqualTo(WarehouseGame.maxActiveDrops));
    });
  });

  group('Boss Grounding & Combat Toughness', () {
    test('Boss maintains solid footing on platform (y = 350) without floating', () async {
      final platform = WarehousePlatform(position: Vector2(645, 350), size: Vector2(790, 20));
      final boss = ViperBoss(position: Vector2(800, 350), groundLevel: 496.0);
      boss.currentPlatform = platform;
      boss.isGrounded = true;

      boss.update(0.02);
      expect(boss.isGrounded, isTrue);
      expect(boss.position.y, equals(350.0));
      expect(boss.currentPlatform, equals(platform));
    });

    test('Boss is tougher with 700 max HP and passive armor', () async {
      final boss = ViperBoss(position: Vector2(800, 350), groundLevel: 496.0);
      expect(boss.maxHealth, equals(700));
      expect(boss.health, equals(700));

      // Boss takes 18 damage attack with 25% armor in Phase 1
      boss.takeDamage(18, 1.0);
      expect(boss.health, equals(700 - (18 * 0.75).round()));
    });
  });
}
