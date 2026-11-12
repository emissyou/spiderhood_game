import 'dart:async';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/ui/moonlit_rooftop_screen.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';

/// Preloads the Moonlit Rooftop Cityscape assets to guarantee zero in-game lag.
class MoonlitLoadingScreen extends StatefulWidget {
  const MoonlitLoadingScreen({super.key});

  @override
  State<MoonlitLoadingScreen> createState() => _MoonlitLoadingScreenState();
}

class _MoonlitLoadingScreenState extends State<MoonlitLoadingScreen> {
  double _progress = 0.0;
  Timer? _progressTimer;
  String _statusText = 'INITIALIZING SKYLINE TRACKING...';
  bool _assetsLoaded = false;
  bool _hasNavigated = false;

  final List<String> _loadingSteps = [
    'SCANNING NIGHT SKYLINE FOR ESCAPING CARTEL...',
    'PRELOADING MOONLIT ROOFTOP CITYSCAPE ASSETS...',
    'CALCULATING WEB ANCHORS & TRAJECTORIES...',
    'POSITIONING HERO ON FIRST BUILDING ROOFTOP...',
    'ALL ASSETS CACHED! LAUNCHING...',
  ];

  @override
  void initState() {
    super.initState();
    _startPreloading();
    _startProgressAnimation();
  }

  Future<void> _startPreloading() async {
    try {
      await Future.wait([
        Flame.images.load('environment/Moonlit Rooftop Cityscape.png'),
        Flame.images.load('player/swing/1.png'),
        Flame.images.load('player/swing/2.png'),
        Flame.images.load('player/attack/punch/1.png'),
        Flame.images.load('player/attack/punch/2.png'),
        Flame.images.load('player/attack/kick/1.png'),
        Flame.images.load('player/attack/kick/2.png'),
        Flame.images.load('player/attack/skill_1/1.png'),
        Flame.images.load('player/running/1.png'),
        Flame.images.load('player/running/2.png'),
        for (int i = 1; i <= 8; i++) Flame.images.load('player/idle/$i.png'),
      ]);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _assetsLoaded = true;
      });
      _checkCompletion();
    }
  }

  void _startProgressAnimation() {
    const totalTicks = 35; // ~1.4 seconds smooth loading bar
    int currentTick = 0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentTick++;
      final currentProgress = (currentTick / totalTicks).clamp(0.0, 1.0);
      final stepIndex = ((currentProgress * (_loadingSteps.length - 1)).floor()).clamp(0, _loadingSteps.length - 1);

      setState(() {
        _progress = currentProgress;
        _statusText = _loadingSteps[stepIndex];
      });

      if (currentTick >= totalTicks) {
        timer.cancel();
        _checkCompletion();
      }
    });
  }

  void _checkCompletion() {
    if (_progress >= 1.0 && _assetsLoaded && !_hasNavigated && mounted) {
      _hasNavigated = true;
      AudioManager.instance.playButtonClick();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => const MoonlitRooftopScreen(),
          transitionsBuilder: (context, anim1, anim2, child) {
            return FadeTransition(opacity: anim1, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Chapter Badge
                  PixelContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    backgroundColor: const Color(0xFF0F172A),
                    borderColor: const Color(0xFF38BDF8),
                    borderWidth: 2,
                    child: const Text(
                      'STORY MODE • CHAPTER 2',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Map Name Title
                  const Text(
                    'MOONLIT ROOFTOP\nCITYSCAPE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      height: 1.2,
                      shadows: [
                        Shadow(color: Color(0xFF0284C7), offset: Offset(2, 2), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Loading Progress Bar
                  PixelProgressBar(
                    progress: _progress,
                    height: 22,
                    fillColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                  const SizedBox(height: 14),

                  // Status Hint Text
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
