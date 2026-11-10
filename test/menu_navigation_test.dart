import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/game/config/game_config.dart';
import 'package:spideyhood/game/ui/loading_screen.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';
import 'package:spideyhood/game/ui/survival_level_screen.dart';

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

  group('Responsive Camera Viewport Calculations', () {
    test('PC and Mobile screen heights yield constant visible height of 160.91', () {
      // Reference screenshot height: 531px -> streetZoom 3.3
      const refHeight = 531.0;
      final refZoom = GameConfig.responsiveStreetZoom(refHeight);
      expect(refZoom, closeTo(3.29998, 0.01));
      expect(refHeight / refZoom, closeTo(GameConfig.targetVisibleHeight, 0.001));

      // Mobile phone landscape (e.g. iPhone / Android 390px):
      const phoneHeight = 390.0;
      final phoneZoom = GameConfig.responsiveStreetZoom(phoneHeight);
      expect(phoneHeight / phoneZoom, closeTo(GameConfig.targetVisibleHeight, 0.001));

      // Tablet / Medium screen (e.g. 720px):
      const tabletHeight = 720.0;
      final tabletZoom = GameConfig.responsiveStreetZoom(tabletHeight);
      expect(tabletHeight / tabletZoom, closeTo(GameConfig.targetVisibleHeight, 0.001));

      // Desktop full HD 1080p:
      const desktopHeight = 1080.0;
      final desktopZoom = GameConfig.responsiveStreetZoom(desktopHeight);
      expect(desktopHeight / desktopZoom, closeTo(GameConfig.targetVisibleHeight, 0.001));
    });
  });

  group('Pixel UI & Menu Navigation Tests', () {
    testWidgets('LoadingScreen renders pixel title, progress bar, and skip/start button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(),
        ),
      );

      expect(find.text('SPIDEYHOOD'), findsWidgets);
      expect(find.byType(PixelProgressBar), findsOneWidget);
      expect(find.text('SKIP LOADING'), findsOneWidget);

      // Fast-forward 3 seconds to complete loading
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('▶ PRESS START'), findsOneWidget);
    });

    testWidgets('ModeSelectScreen displays Story Mode and Survival Mode options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ModeSelectScreen(),
        ),
      );

      expect(find.text('STORY MODE'), findsOneWidget);
      expect(find.text('SURVIVAL MODE'), findsOneWidget);
      expect(find.text('PLAY STORY MODE ▶'), findsOneWidget);
      expect(find.text('ENTER SURVIVAL ▶'), findsOneWidget);

      // Tapping Play Story Mode navigates to StoryIntroScreen
      await tester.tap(find.text('PLAY STORY MODE ▶'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STORY MODE: PART 1 • (1/7)'), findsOneWidget);
    });

    testWidgets('SurvivalLevelScreen displays 3 levels with Level 1 unlocked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SurvivalLevelScreen(),
        ),
      );

      expect(find.text('SURVIVAL MODE: SELECT LEVEL'), findsOneWidget);
      expect(find.text('SIDEWALK PATROL'), findsOneWidget);
      expect(find.text('ROOFTOP SHOWDOWN'), findsOneWidget);
      expect(find.text('MIDTOWN MAYHEM'), findsOneWidget);

      expect(find.text('▶ START PATROL'), findsOneWidget);
      expect(find.text('🔒 LOCKED'), findsNWidgets(2));

      // Tapping a locked level shows requirement modal
      await tester.tap(find.text('🔒 LOCKED').first);
      await tester.pumpAndSettle();
      expect(find.text('LEVEL 2: ROOFTOP SHOWDOWN'), findsOneWidget);
      expect(
        find.textContaining('Clear Level 1 with 1,000+ points'),
        findsOneWidget,
      );

      await tester.tap(find.text('UNDERSTOOD'));
      await tester.pumpAndSettle();
    });
  });
}
