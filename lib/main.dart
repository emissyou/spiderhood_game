import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/services/audio_manager.dart';
import 'game/spidey_game.dart';
import 'game/ui/comic_hud.dart';
import 'game/ui/loading_screen.dart';
import 'game/ui/mode_select_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive landscape orientation for comic-book arcade action
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize background audio engine
  await AudioManager.instance.initialize();

  runApp(const SpideyhoodApp());
}

class SpideyhoodApp extends StatelessWidget {
  const SpideyhoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spideyhood',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const LoadingScreen(),
    );
  }
}

class SpideyhoodGameScreen extends StatefulWidget {
  const SpideyhoodGameScreen({super.key});

  @override
  State<SpideyhoodGameScreen> createState() => _SpideyhoodGameScreenState();
}

class _SpideyhoodGameScreenState extends State<SpideyhoodGameScreen> {
  late final SpideyGame _game;

  @override
  void initState() {
    super.initState();
    _game = SpideyGame();
    _game.onExitToMenu = () {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
          );
        }
      }
    };
  }

  @override
  void dispose() {
    _game.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<SpideyGame>(
        game: _game,
        overlayBuilderMap: {
          'ComicHud': (context, game) => ComicHud(game: game),
        },
        initialActiveOverlays: const ['ComicHud'],
      ),
    );
  }
}
