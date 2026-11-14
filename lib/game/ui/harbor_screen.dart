import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/harbor_game.dart';
import 'package:spideyhood/game/ui/harbor_hud.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/story_intro_screen.dart';

/// Screen hosting Manhattan Harbor mission (Story Mode Chapter 3).
class HarborScreen extends StatefulWidget {
  const HarborScreen({super.key});

  @override
  State<HarborScreen> createState() => _HarborScreenState();
}

class _HarborScreenState extends State<HarborScreen> {
  late final HarborGame _game;

  @override
  void initState() {
    super.initState();
    _game = HarborGame();
    _game.onRestartPart = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HarborScreen()),
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
          MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget<HarborGame>(
        game: _game,
        overlayBuilderMap: {
          'HarborHud': (context, game) => HarborHud(game: game),
        },
        initialActiveOverlays: const ['HarborHud'],
      ),
    );
  }
}
