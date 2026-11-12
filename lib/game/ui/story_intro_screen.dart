import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/moonlit_loading_screen.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';
import 'package:spideyhood/game/ui/story_quest_hud.dart';

/// Reusable Cinematic Comic Slides Viewer for Story Mode scenarios.
/// Provides:
/// - Maximum screen real estate for large, immersive comic artwork.
/// - Segmented real-time progress bar.
/// - Per-slide Skip button unlocked ONLY when the slide reaches half-way (50% progress).
class StoryViewerScreen extends StatefulWidget {
  final String modeBadgeText;
  final List<String> images;
  final List<String> captions;
  final VoidCallback onComplete;
  final VoidCallback? onBackToMenu;

  const StoryViewerScreen({
    super.key,
    required this.modeBadgeText,
    required this.images,
    required this.captions,
    required this.onComplete,
    this.onBackToMenu,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  int _currentIndex = 0;
  double _currentProgress = 0.0;
  Timer? _tickerTimer;
  static const int _ticksPerSlide = 40; // 40 * 100ms = 4.0 seconds per slide
  int _currentTick = 0;

  bool get canSkipCurrentSlide => _currentProgress >= 0.50;

  @override
  void initState() {
    super.initState();
    if (!AudioManager.instance.isMuted && !AudioManager.instance.isPlaying) {
      AudioManager.instance.playBgm();
    }
    _startSlideTimer();
  }

  void _startSlideTimer() {
    _tickerTimer?.cancel();
    _currentTick = 0;
    _currentProgress = 0.0;

    _tickerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _currentTick++;
      setState(() {
        _currentProgress = (_currentTick / _ticksPerSlide).clamp(0.0, 1.0);
      });

      if (_currentTick >= _ticksPerSlide) {
        _advanceSlide();
      }
    });
  }

  void _advanceSlide() {
    if (!mounted) return;
    AudioManager.instance.playButtonClick();
    if (_currentIndex < widget.images.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startSlideTimer();
    } else {
      _tickerTimer?.cancel();
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.images[_currentIndex];
    final caption = _currentIndex < widget.captions.length ? widget.captions[_currentIndex] : '';

    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AudioManager.instance.resumeBgmIfSuspended();
        },
        child: Stack(
          children: [
            // Ambient Dark Comic Vignette Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [
                      Color(0xFF141929),
                      Color(0xFF07090F),
                    ],
                  ),
                ),
              ),
            ),

            // Main Cinematic Comic Slide Image Display (Enlarged to fill maximum viewport)
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 48.0, 10.0, 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1350, maxHeight: 820),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.70),
                        width: 3.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                        const BoxShadow(
                          color: Colors.black87,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Animated Crossfade between images (Large, crisp presentation)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 550),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Image.asset(
                            imagePath,
                            key: ValueKey<String>(imagePath),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  'SCENE ${_currentIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Bottom Comic Caption Overlay Banner with Integrated Per-Slide Skip Button
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.95),
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    caption,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.8,
                                      shadows: [
                                        Shadow(color: Colors.black, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Per-Slide Skip Button: Unlocked strictly when slide is half way (50%)
                                if (canSkipCurrentSlide)
                                  PixelButton(
                                    text: 'SKIP SLIDE ▶',
                                    color: const Color(0xFFF59E0B),
                                    textColor: Colors.black,
                                    fontSize: 11,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    onPressed: _advanceSlide,
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white24, width: 1),
                                    ),
                                    child: Text(
                                      'SKIP IN ${( (0.50 - _currentProgress) * 4.0 ).clamp(0.1, 2.0).toStringAsFixed(1)}s',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top Status Bar: Back to Menu, Mode Badge, and Scene Counter
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PixelButton(
                      text: '◀ MENU',
                      color: Colors.white12,
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      onPressed: () {
                        _tickerTimer?.cancel();
                        if (widget.onBackToMenu != null) {
                          widget.onBackToMenu!();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
                          );
                        }
                      },
                    ),
                    PixelBadge(
                      text: '${widget.modeBadgeText} • (${_currentIndex + 1}/${widget.images.length})',
                      color: const Color(0xFF00F0FF),
                      textColor: Colors.black,
                      icon: Icons.movie_filter,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Progress Bar: Segmented auto-slide indicator
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      children: List.generate(widget.images.length, (index) {
                        final isCompleted = index < _currentIndex;
                        final isCurrent = index == _currentIndex;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(0xFF00F0FF)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: isCompleted
                                  ? 1.0
                                  : isCurrent
                                      ? _currentProgress
                                      : 0.0,
                              child: Container(
                                color: isCurrent
                                    ? const Color(0xFF00F0FF)
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cinematic Story Mode Introduction for Part 1: Starting Scenario.
class StoryIntroScreen extends StatelessWidget {
  const StoryIntroScreen({super.key});

  static const List<String> part1Images = [
    'assets/images/story/part_1/starting_scenario/1.jpg',
    'assets/images/story/part_1/starting_scenario/2.jpg',
    'assets/images/story/part_1/starting_scenario/3.jpg',
    'assets/images/story/part_1/starting_scenario/4.png',
    'assets/images/story/part_1/starting_scenario/5.png',
    'assets/images/story/part_1/starting_scenario/6.png',
    'assets/images/story/part_1/starting_scenario/7.png',
  ];

  static const List<String> storyCaptions = [
    'SCENE 1: AN ORDINARY MORNING IN MANHATTAN SHATTERED BY HIGH EXPLOSIVES',
    'SCENE 2: SPIDER-MAN SWOOPS INTO ACTION TO INTERCEPT THE HEAVILY ARMED SYNDICATE',
    'SCENE 3: A HEATED FIREFIGHT ERUPTS INSIDE THE SHATTERED BANK VAULT',
    'SCENE 4: SPIDER-MAN DISARMS THE GANG WITH ACROBATIC WEB-COMBAT STRIKES',
    'SCENE 5: THE FLEEING LEADER DROPS A GLOWING CLASSIFIED MILITARY TECH DRIVE',
    'SCENE 6: SPIDER-MAN DECRYPTS THE DATA: THE VIPERS ARE GATHERING LETHAL WEAPON CORES',
    'SCENE 7: COORDINATES UNLOCKED — INFILTRATE THE WATERFRONT ABANDONED WAREHOUSE!',
  ];

  @override
  Widget build(BuildContext context) {
    return StoryViewerScreen(
      modeBadgeText: 'STORY MODE: PART 1',
      images: part1Images,
      captions: storyCaptions,
      onComplete: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const WarehouseGameScreen(),
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      onBackToMenu: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
        );
      },
    );
  }
}

/// Cinematic Ending Scenario triggered when the Boss escapes.
class StoryEscapeScreen extends StatelessWidget {
  const StoryEscapeScreen({super.key});

  static const List<String> escapeImages = [
    'assets/images/story/part_1/escape_scenario/1.png',
    'assets/images/story/part_1/escape_scenario/2.png',
  ];

  static const List<String> escapeCaptions = [
    'SCENE 1: THE VIPER WARLORD BLASTS THROUGH THE SECURITY BULKHEAD AND FLEES INTO THE CITY!',
    'SCENE 2: SPIDER-MAN RECOVERS THE ESCAPE FLIGHT LOGS: THE TRAIL LEADS TO VULTURE\'S SKY FORTRESS!',
  ];

  @override
  Widget build(BuildContext context) {
    return StoryViewerScreen(
      modeBadgeText: 'STORY MODE: PART 1 • ESCAPE SCENARIO',
      images: escapeImages,
      captions: escapeCaptions,
      onComplete: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const StoryBlackoutScreen(
              nextScreen: StoryAfterEscapeScreen(),
              duration: Duration(milliseconds: 1000),
            ),
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      onBackToMenu: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
        );
      },
    );
  }
}

/// Seamless blackout transition screen displayed between story segments.
class StoryBlackoutScreen extends StatefulWidget {
  final Widget nextScreen;
  final Duration duration;

  const StoryBlackoutScreen({
    super.key,
    required this.nextScreen,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<StoryBlackoutScreen> createState() => _StoryBlackoutScreenState();
}

class _StoryBlackoutScreenState extends State<StoryBlackoutScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => widget.nextScreen,
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(),
    );
  }
}

/// Cinematic After-Escape Scenario (Second Story) triggered after the Escape Scenario.
class StoryAfterEscapeScreen extends StatelessWidget {
  const StoryAfterEscapeScreen({super.key});

  static const List<String> afterEscapeImages = [
    'assets/images/story/part_1/after_escape_scenario/1.png',
    'assets/images/story/part_1/after_escape_scenario/2.png',
  ];

  static const List<String> afterEscapeCaptions = [
    'SCENE 1: SPIDER-MAN PERCHES ABOVE THE CITY SKYLINE, SCANNING THE NIGHT FOR TRACES OF THE ESCAPED WARLORD.',
    'SCENE 2: AN ENCRYPTED VIPER SIGNAL IS DETECTED ACROSS THE BAY: THE HUNT CONTINUES!',
  ];

  @override
  Widget build(BuildContext context) {
    return StoryViewerScreen(
      modeBadgeText: 'STORY MODE: PART 1 • AFTER ESCAPE SCENARIO',
      images: afterEscapeImages,
      captions: afterEscapeCaptions,
      onComplete: () {
        // Save progress to Part 2 checkpoint
        StoryProgressService.instance.completePart1();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const MoonlitLoadingScreen(),
            transitionsBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      onBackToMenu: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
        );
      },
    );
  }
}

/// Host widget for Flame Game running WarehouseGame (Scenario 1: Abandoned Warehouse).
class WarehouseGameScreen extends StatefulWidget {
  const WarehouseGameScreen({super.key});

  @override
  State<WarehouseGameScreen> createState() => _WarehouseGameScreenState();
}

class _WarehouseGameScreenState extends State<WarehouseGameScreen> {
  late final WarehouseGame _game;

  @override
  void initState() {
    super.initState();
    _game = WarehouseGame();
    _game.onRestartPart = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WarehouseGameScreen()),
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
    _game.onTriggerEscapeScenario = () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const StoryBlackoutScreen(
              nextScreen: StoryEscapeScreen(),
              duration: Duration(milliseconds: 1000),
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
      body: GameWidget<WarehouseGame>(
        game: _game,
        overlayBuilderMap: {
          'StoryQuestHud': (context, game) => StoryQuestHud(game: game),
        },
        initialActiveOverlays: const ['StoryQuestHud'],
      ),
    );
  }
}
