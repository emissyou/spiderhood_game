import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import 'mode_select_screen.dart';
import 'pixel_widgets.dart';

/// Pixelated retro arcade loading page for mobile and desktop.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0.0;
  Timer? _loadingTimer;
  Timer? _idleAnimTimer;
  int _idleFrame = 1;
  String _statusText = 'INITIALIZING NEW YORK STREETS...';
  bool _isReady = false;

  final List<String> _loadingSteps = [
    'CALIBRATING SPIDER-SENSE...',
    'CHARGING FLUID IN WEB-SHOOTERS...',
    'DISPATCHING MORNING YELLOW TAXIS...',
    'LOCATING SIDEWALK CIVILIANS & THUGS...',
    'TUNING MANHATTAN PATROL ROUTE...',
    'SYSTEMS READY! PRESS START!',
  ];

  @override
  void initState() {
    super.initState();
    AudioManager.instance.playBgm();
    _startLoading();
    _startIdleAnimation();
  }

  void _startIdleAnimation() {
    _idleAnimTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (!mounted) return;
      setState(() {
        _idleFrame = (_idleFrame % 11) + 1;
      });
    });
  }

  void _startLoading() {
    const totalTicks = 50;
    int currentTick = 0;

    _loadingTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentTick++;
      final currentProgress = (currentTick / totalTicks).clamp(0.0, 1.0);
      final stepIndex = ((currentProgress * (_loadingSteps.length - 1)).floor())
          .clamp(0, _loadingSteps.length - 1);

      setState(() {
        _progress = currentProgress;
        _statusText = _loadingSteps[stepIndex];
      });

      if (currentTick >= totalTicks) {
        timer.cancel();
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  void _proceedToModeSelect() {
    if (!mounted) return;
    AudioManager.instance.resumeBgmIfSuspended();
    _loadingTimer?.cancel();
    _idleAnimTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const ModeSelectScreen(),
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _idleAnimTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Stack(
        children: [
          // Subtle Pixel Grid Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/environment/new_york_morning.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),

          // Scanline / vignette atmosphere
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Arcade Badge
                    const PixelBadge(
                      text: '★ RETRO ARCADE ACTION ★',
                      color: PixelColors.yellow,
                      textColor: Colors.black,
                      icon: Icons.flash_on,
                    ),
                    const SizedBox(height: 12),

                    // Game Title with 3D drop effect
                    Stack(
                      children: [
                        Text(
                          'SPIDEYHOOD',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 3.5,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 6
                              ..color = Colors.black,
                          ),
                        ),
                        Text(
                          'SPIDEYHOOD',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 3.5,
                            color: PixelColors.red,
                            shadows: const [
                              Shadow(color: Colors.white, offset: Offset(2, 2)),
                              Shadow(color: Colors.black, offset: Offset(5, 5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'NEIGHBORHOOD HERO • MANHATTAN STREETS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Animated Character Preview Frame with Neon Glow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: PixelColors.yellow.withValues(alpha: 0.12),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: PixelContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        backgroundColor: const Color(0xFF14192D),
                        borderColor: PixelColors.yellow,
                        borderWidth: 2.5,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Subtle floor spotlight
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF38BDF8).withValues(alpha: 0.22),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    SizedBox(
                                      height: 72,
                                      width: 60,
                                      child: Image.asset(
                                        'assets/images/player/idle/$_idleFrame.png',
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.person,
                                          color: PixelColors.red,
                                          size: 50,
                                        ),
                                      ),
                                    ),
                                    // Drop shadow under feet
                                    Container(
                                      width: 36,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PixelColors.yellow,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Pixel segmented progress bar
                            PixelProgressBar(
                              progress: _progress,
                              height: 16,
                              fillColor: PixelColors.green,
                              totalSegments: 18,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'STATUS: LOADING',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: PixelColors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Start Action Button (Appears when ready, clean pulsing retro design)
                    if (_isReady)
                      PixelButton(
                        text: '▶ PRESS START',
                        icon: Icons.play_arrow,
                        color: PixelColors.green,
                        textColor: Colors.black,
                        fontSize: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                        onPressed: _proceedToModeSelect,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'LOADING ASSETS...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Version Note
          const Positioned(
            bottom: 12,
            right: 16,
            child: Text(
              'SPIDEYHOOD v1.0.0 • 2026',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Top-right Audio Mute Button
          Positioned(
            top: 14,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  AudioManager.instance.toggleMute();
                });
              },
              child: PixelContainer(
                padding: const EdgeInsets.all(8),
                backgroundColor: AudioManager.instance.isMuted
                    ? Colors.grey.shade900
                    : const Color(0xFF1B2038),
                borderColor: Colors.white,
                borderWidth: 2,
                elevation: 2,
                child: Icon(
                  AudioManager.instance.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: AudioManager.instance.isMuted ? Colors.white38 : PixelColors.yellow,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
