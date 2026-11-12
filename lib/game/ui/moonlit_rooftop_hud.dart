import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/moonlit_rooftop_game.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';
import 'package:spideyhood/game/ui/story_intro_screen.dart';

/// Interactive HUD and controls overlay for Moonlit Rooftop Cityscape.
class MoonlitRooftopHud extends StatefulWidget {
  final MoonlitRooftopGame game;

  const MoonlitRooftopHud({super.key, required this.game});

  @override
  State<MoonlitRooftopHud> createState() => _MoonlitRooftopHudState();
}

class _MoonlitRooftopHudState extends State<MoonlitRooftopHud> {
  Timer? _refreshTimer;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final audio = AudioManager.instance;

    return SafeArea(
      child: Stack(
        children: [
          // Top Left: Map title, Health Hearts, Web Fluid
          Positioned(
            top: 14,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map Title Banner
                PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: const Color(0xFF0F172A),
                  borderColor: const Color(0xFF38BDF8),
                  borderWidth: 2.0,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.nightlight_round, color: Color(0xFF38BDF8), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'MOONLIT ROOFTOP CITYSCAPE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 5 Hearts Health Bar
                PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: const Color(0xFF1E293B),
                  borderColor: const Color(0xFF64748B),
                  borderWidth: 1.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < Spidey.maxHealth; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Icon(
                            i < game.player.health ? Icons.favorite : Icons.favorite_border,
                            color: i < game.player.health ? const Color(0xFFEF4444) : Colors.white24,
                            size: 18,
                          ),
                        ),
                      if (game.player.shieldTimer > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.shield, color: Color(0xFFFACC15), size: 16),
                      ],
                      if (game.player.activeGodMode) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, color: Colors.black, size: 11),
                              Text(
                                'GODMODE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Web Fluid Gauge
                PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  backgroundColor: const Color(0xFF1E293B),
                  borderColor: const Color(0xFF64748B),
                  borderWidth: 1.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.blur_on, color: Color(0xFF38BDF8), size: 14),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 80,
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (game.player.webFluid / Spidey.maxWebFluid).clamp(0.0, 1.0),
                            backgroundColor: Colors.black45,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${game.player.webFluid.toInt()}',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top Right: Audio Toggle & Exit Button
          Positioned(
            top: 14,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      audio.toggleMute();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: Icon(
                      audio.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: audio.isMuted ? Colors.white54 : Colors.yellowAccent,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isMenuOpen = !_isMenuOpen;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'MENU',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Controls (Bottom Left: 4-Way D-Pad: UP=Jump, DOWN=Platform Drop, LEFT/RIGHT=Move)
          Positioned(
            bottom: 20,
            left: 18,
            child: _buildDpad(
              onUp: () => game.jump(),
              onDown: () => game.dropDownPlatform(),
              onLeftDown: () => game.startMoveLeft(),
              onLeftUp: () => game.stopMove(),
              onRightDown: () => game.startMoveRight(),
              onRightUp: () => game.stopMove(),
            ),
          ),

          // Controls (Bottom Right: Actions - identical style to Part 1, without JUMP button)
          Positioned(
            bottom: 24,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  label: 'PUNCH',
                  subtitle: '18 DMG',
                  color: const Color(0xFFD62828),
                  onTap: () => game.punch(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'KICK',
                  subtitle: '32 DMG',
                  color: const Color(0xFFF77F00),
                  onTap: () => game.kick(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'SKILL',
                  subtitle: game.player.skill1Cooldown > 0
                      ? '${game.player.skill1Cooldown.toStringAsFixed(1)}s'
                      : 'WEB SHOT',
                  color: game.player.skill1Cooldown > 0 ? const Color(0xFF4A148C) : const Color(0xFF7209B7),
                  onTap: game.player.skill1Cooldown > 0 ? null : () => game.useSkill(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'SWING',
                  subtitle: '${game.player.webFluid.clamp(0, 10).toInt()}/10 WEB',
                  color: game.player.webFluid < 1.0 ? const Color(0xFF374151) : const Color(0xFF028090),
                  onTap: () => game.shootWebAhead(),
                ),
              ],
            ),
          ),

          // Story Menu & Game Over Dialog
          if (_isMenuOpen || game.player.health <= 0)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: SingleChildScrollView(
                    child: PixelContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      backgroundColor: const Color(0xFF0F172A),
                      borderColor: game.player.health <= 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF38BDF8),
                      borderWidth: 2.5,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              game.player.health <= 0 ? 'MISSION FAILED' : 'PAUSED',
                              style: TextStyle(
                                color: game.player.health <= 0
                                    ? const Color(0xFFEF4444)
                                    : Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'STORY MODE • PART 2: MOONLIT ROOFTOP',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (game.player.health > 0) ...[
                              PixelButton(
                                text: 'RESUME MISSION ▶',
                                color: const Color(0xFF38BDF8),
                                textColor: Colors.black,
                                fontSize: 12,
                                onPressed: () {
                                  setState(() {
                                    _isMenuOpen = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                            PixelButton(
                              text: 'RESTART THIS PART ↺',
                              color: const Color(0xFFF59E0B),
                              textColor: Colors.black,
                              fontSize: 12,
                              onPressed: () {
                                game.onRestartPart?.call();
                              },
                            ),
                            const SizedBox(height: 10),
                            PixelButton(
                              text: 'RESTART STORY FROM BEGINNING ↺',
                              color: const Color(0xFFEF4444),
                              textColor: Colors.white,
                              fontSize: 11,
                              onPressed: () {
                                game.onRestartStory?.call();
                              },
                            ),
                            const SizedBox(height: 10),
                            PixelButton(
                              text: game.player.activeGodMode
                                  ? '⚡ GODMODE: ON (IMMORTAL)'
                                  : '⚡ GODMODE: OFF',
                              color: game.player.activeGodMode
                                  ? const Color(0xFFF59E0B)
                                  : Colors.white24,
                              textColor: game.player.activeGodMode ? Colors.black : Colors.white70,
                              fontSize: 11,
                              onPressed: () {
                                setState(() {
                                  game.player.isGodMode = !game.player.activeGodMode;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            PixelButton(
                              text: 'GO TO PART 1 (WAREHOUSE) ▶',
                              color: const Color(0xFF10B981),
                              textColor: Colors.black,
                              fontSize: 11,
                              onPressed: () async {
                                AudioManager.instance.resumeBgmIfSuspended();
                                await StoryProgressService.instance.saveProgress(1);
                                if (context.mounted) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            PixelButton(
                              text: 'EXIT TO MAIN MENU ◀',
                              color: Colors.white24,
                              textColor: Colors.white,
                              fontSize: 11,
                              onPressed: () {
                                game.onExitToMenu?.call();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDpad({
    required VoidCallback onUp,
    required VoidCallback onDown,
    required VoidCallback onLeftDown,
    required VoidCallback onLeftUp,
    required VoidCallback onRightDown,
    required VoidCallback onRightUp,
  }) {
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        children: [
          // Center hub connector
          Positioned(
            top: 46,
            left: 46,
            width: 46,
            height: 46,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.circle, color: Colors.white30, size: 8),
              ),
            ),
          ),
          // UP: Jump
          Positioned(
            top: 0,
            left: 46,
            width: 46,
            height: 46,
            child: _buildDpadButton(
              icon: Icons.arrow_upward,
              label: 'JUMP',
              onDown: onUp,
            ),
          ),
          // DOWN: Drop Down Platform
          Positioned(
            bottom: 0,
            left: 46,
            width: 46,
            height: 46,
            child: _buildDpadButton(
              icon: Icons.arrow_downward,
              label: 'DOWN',
              onDown: onDown,
            ),
          ),
          // LEFT: Move Left
          Positioned(
            top: 46,
            left: 0,
            width: 46,
            height: 46,
            child: _buildDpadButton(
              icon: Icons.arrow_back,
              onDown: onLeftDown,
              onUp: onLeftUp,
            ),
          ),
          // RIGHT: Move Right
          Positioned(
            top: 46,
            right: 0,
            width: 46,
            height: 46,
            child: _buildDpadButton(
              icon: Icons.arrow_forward,
              onDown: onRightDown,
              onUp: onRightUp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDpadButton({
    required IconData icon,
    String? label,
    required VoidCallback onDown,
    VoidCallback? onUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp?.call(),
      onTapCancel: () => onUp?.call(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, offset: Offset(2, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: label != null ? 20 : 24),
            if (label != null)
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.55,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
