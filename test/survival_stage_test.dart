import 'dart:convert';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/actors/civilian.dart';
import 'package:spideyhood/game/actors/enemies/thug.dart';
import 'package:spideyhood/game/components/falling_leaves.dart';
import 'package:spideyhood/game/components/taxi.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/spidey_game.dart';

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
  });

  group('Survival Stage 1 Tests', () {
    test('Thug stays firmly grounded on sidewalk and does not fall into infinity', () async {
      final thug = Thug(position: Vector2(950, GameConfig.groundY));
      await thug.onLoad();

      expect(thug.position.y, GameConfig.groundY);

      // Simulate 10 seconds of physics gravity updates
      for (int i = 0; i < 600; i++) {
        thug.update(0.016);
      }

      // Must remain firmly clamped to groundY, not fall into the abyss
      expect(thug.position.y, GameConfig.groundY);
      expect(thug.isGrounded, isTrue);
      expect(thug.velocity.y, 0.0);
    });

    test('Taxi loops horizontally without crashing or stacking', () async {
      final taxi = Taxi(position: Vector2(100, 750), taxiIndex: 1);
      await taxi.onLoad();

      for (int i = 0; i < 60; i++) {
        taxi.update(0.016);
      }

      expect(taxi.position.y, 750.0);
      expect(taxi.position.x, greaterThan(100.0));
      taxi.onRemove();
    });

    test('Civilian walks and patrols within sidewalk bounds', () async {
      final civilian = Civilian(position: Vector2(200, GameConfig.groundY), variant: 1);
      await civilian.onLoad();

      for (int i = 0; i < 60; i++) {
        civilian.update(0.016);
      }

      expect(civilian.position.y, GameConfig.groundY);
      expect(civilian.position.x, isNot(200.0));
    });

    test('FallingLeavesSystem updates without errors', () async {
      final leaves = FallingLeavesSystem();
      await leaves.onLoad();

      expect(() => leaves.update(0.016), returnsNormally);
    });

    test('SpideyGame initializes survival stage 1 entities', () async {
      final game = SpideyGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      expect(game.world.children.whereType<Thug>().length, 2);
      expect(game.world.children.whereType<Taxi>().length, 1);
      expect(game.world.children.whereType<Civilian>().length, 2);
      expect(game.anchors.length, 11);
    });

    test('Camera viewfinder updates position following player', () async {
      final game = SpideyGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final initialCamX = game.camera.viewfinder.position.x;
      // Move player forward
      game.player.position.x = 800;
      game.update(0.1);

      expect(game.camera.viewfinder.position.x, isNot(initialCamX));
      expect(game.camera.viewfinder.position.x, closeTo(800.0, 50.0));
    });
  });
}
