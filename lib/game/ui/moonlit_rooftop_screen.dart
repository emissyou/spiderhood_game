import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/moonlit_rooftop_game.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/moonlit_rooftop_hud.dart';
import 'package:spideyhood/game/ui/story_intro_screen.dart';

/// Screen hosting Moonlit Rooftop Cityscape mission.
class MoonlitRooftopScreen extends StatefulWidget {
  const MoonlitRooftopScreen({super.key});

  @override
  State<MoonlitRooftopScreen> createState() => _MoonlitRooftopScreenState();
}

class _MoonlitRooftopScreenState extends State<MoonlitRooftopScreen> {
  late final MoonlitRooftopGame _game;

  @override
  void initState() {
    super.initState();
    _game = MoonlitRooftopGame();
    _game.onRestartPart = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MoonlitRooftopScreen()),
        );
      }
    };
    _game.onRestartStory = () async {
      await StoryProgressService.instance.resetStory();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
        );
      }
    };
    _game.onExitToMenu = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
        );
      }
    };
    _game.onMissionComplete = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const StoryBlackoutScreen(
              nextScreen: StoryPart2Screen(),
              duration: Duration(milliseconds: 800),
            ),
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget<MoonlitRooftopGame>(
        game: _game,
        overlayBuilderMap: {
          'MoonlitRooftopHud': (context, game) => MoonlitRooftopHud(game: game),
        },
        initialActiveOverlays: const ['MoonlitRooftopHud'],
      ),
    );
  }
}
