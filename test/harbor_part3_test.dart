import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/actors/enemies/minion_with_gun.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/harbor_background.dart';
import 'package:spideyhood/game/story/harbor_game.dart';
import 'package:spideyhood/game/ui/harbor_hud.dart';
import 'package:spideyhood/game/ui/harbor_loading_screen.dart';
import 'package:spideyhood/game/ui/harbor_screen.dart';
import 'package:spideyhood/game/ui/story_intro_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 2 to Part 3 Transition & Harbor Mission Tests', () {
    test('StoryProgressService supports Chapter 3 Manhattan Harbor progression', () async {
      final story = StoryProgressService.instance;
      await story.completePart2();
      expect(story.currentPart, equals(3));
      expect(story.maxPartReached, greaterThanOrEqualTo(3));
      expect(story.currentPartTitle, equals('PART 3: MANHATTAN HARBOR'));
      expect(story.isPartUnlocked(3), isTrue);

      // Can switch between unlocked parts
      await story.setPart(2);
      expect(story.currentPart, equals(2));
      await story.setPart(3);
      expect(story.currentPart, equals(3));
    });

    testWidgets('StoryPart2Screen displays comic slides and completes to Chapter 3', (tester) async {
      final story = StoryProgressService.instance;
      await story.setPart(2);

      await tester.pumpWidget(
        const MaterialApp(
          home: StoryPart2Screen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('CHAPTER 2'), findsWidgets);
      expect(StoryPart2Screen.part2Images.length, equals(2));
      expect(StoryPart2Screen.part2Images[0], equals('assets/images/story/part_2/1.png'));
      expect(StoryPart2Screen.part2Images[1], equals('assets/images/story/part_2/2.png'));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('HarborLoadingScreen renders Chapter 3 badge, title and progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HarborLoadingScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('STORY MODE • CHAPTER 3'), findsOneWidget);
      expect(find.textContaining('MANHATTAN HARBOR'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    test('HarborGame loads map dimensions, platforms, crane anchors, and Spidey', () async {
      final game = HarborGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Map dimensions (2172 x 724)
      expect(HarborGame.mapWidth, equals(2172.0));
      expect(HarborGame.mapHeight, equals(724.0));
      expect(HarborBackground.mapWidth, equals(2172.0));
      expect(HarborBackground.mapHeight, equals(724.0));

      // Spidey initial spawn
      expect(game.player, isNotNull);
      expect(game.player.position.x, equals(80.0));
      expect(game.player.position.y, equals(560.0));

      // Platforms, web anchors, and guards
      expect(game.platforms.length, greaterThanOrEqualTo(5));
      expect(game.anchors.length, greaterThanOrEqualTo(4));
      expect(game.world.children.whereType<ViperGuard>().length, equals(3));
      expect(game.shipMarksman, isNotNull);
      expect(game.totalEnemies, equals(4));
    });

    test('Harbor camera viewport fits screen height properly without stretching', () {
      final zoomAt600 = HarborGame.responsiveStreetZoom(600);
      expect(zoomAt600, closeTo(600 / 420.0, 0.01));

      final zoomAt420 = HarborGame.responsiveStreetZoom(420);
      expect(zoomAt420, closeTo(1.0, 0.01));

      final swingZoom = HarborGame.responsiveSwingZoom(600);
      expect(swingZoom, closeTo(600 / 520.0, 0.01));
    });

    testWidgets('HarborHud renders HUD controls, D-pad, and actions', (tester) async {
      final game = HarborGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HarborHud(game: game),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PUNCH'), findsOneWidget);
      expect(find.text('KICK'), findsOneWidget);
      expect(find.text('SKILL'), findsOneWidget);
      expect(find.text('SWING'), findsOneWidget);
      expect(find.textContaining('HARBOR'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    test('Harbor mission completes when all 4 enemies are defeated', () async {
      final game = HarborGame();
      bool missionDone = false;
      game.onMissionComplete = () {
        missionDone = true;
      };
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final guards = game.world.children.whereType<ViperGuard>().toList();
      for (final guard in guards) {
        guard.takeDamage(200, 1.0);
      }

      game.shipMarksman.takeDamage(200);
      expect(game.defeatedEnemies, equals(4));

      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(missionDone, isTrue);
    });
  });
}
