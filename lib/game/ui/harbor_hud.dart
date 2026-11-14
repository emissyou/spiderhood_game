import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/harbor_game.dart';
import 'package:spideyhood/game/ui/mode_select_screen.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';

/// Interactive HUD and controls overlay for Harbor Docks (Part 3).
class HarborHud extends StatefulWidget {
  final HarborGame game;

  const HarborHud({super.key, required this.game});

  @override
  State<HarborHud> createState() => _HarborHudState();
}

class _HarborHudState extends State<HarborHud> {
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
                      Icon(Icons.directions_boat, color: Color(0xFF38BDF8), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'MANHATTAN HARBOR DOCKS',
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
                const SizedBox(height: 5),

                // Mission Objective Banner
                PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  backgroundColor: const Color(0xFF0C4A6E),
                  borderColor: game.defeatedEnemies >= game.totalEnemies
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF38BDF8),
                  borderWidth: 1.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        game.defeatedEnemies >= game.totalEnemies
                            ? Icons.check_circle
                            : Icons.gps_fixed,
                        color: game.defeatedEnemies >= game.totalEnemies
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF38BDF8),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'MISSION: SECURE HARBOR (${game.defeatedEnemies}/${game.totalEnemies})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 3 Hearts Health Bar
                PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: const Color(0xFF1E293B),
                  borderColor: const Color(0xFF64748B),
                  borderWidth: 1.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < game.player.effectiveMaxHealth; i++)
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

          // Controls (Bottom Left: 4-Way D-Pad: UP=Jump, DOWN=Drop, LEFT/RIGHT=Move)
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

          // Controls (Bottom Right: Actions)
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
                  subtitle: game.player.swingCooldown > 0
                      ? '${game.player.swingCooldown.toStringAsFixed(1)}s'
                      : '${game.player.webFluid.clamp(0, 10).toInt()}/10 WEB',
                  color: (game.player.webFluid < 1.0 || game.player.swingCooldown > 0)
                      ? const Color(0xFF374151)
                      : const Color(0xFF028090),
                  onTap: game.player.swingCooldown > 0 ? null : () => game.shootWebAhead(),
                ),
              ],
            ),
          ),

          // Pause / Story Menu Overlay
          if (_isMenuOpen || game.player.health <= 0)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: PixelContainer(
                    padding: const EdgeInsets.all(24),
                    backgroundColor: const Color(0xFF0F172A),
                    borderColor: const Color(0xFF38BDF8),
                    borderWidth: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.player.health <= 0 ? 'HERO DEFEATED' : 'PAUSED',
                          style: TextStyle(
                            color: game.player.health <= 0 ? const Color(0xFFEF4444) : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 18),
                        PixelButton(
                          text: game.player.health <= 0 ? 'RETRY MISSION ↺' : 'RESUME ▶',
                          color: const Color(0xFF22C55E),
                          onPressed: () {
                            if (game.player.health <= 0) {
                              game.onRestartPart?.call();
                            } else {
                              setState(() {
                                _isMenuOpen = false;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        PixelButton(
                          text: 'MAIN MENU ❖',
                          color: const Color(0xFFD62828),
                          onPressed: () {
                            if (game.onExitToMenu != null) {
                              game.onExitToMenu!();
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTap?.call(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black87, offset: Offset(2, 3)),
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
                fontSize: 10.5,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
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
    const btnSize = 42.0;

    return SizedBox(
      width: btnSize * 3,
      height: btnSize * 3,
      child: Stack(
        children: [
          // UP: Jump
          Align(
            alignment: Alignment.topCenter,
            child: _buildDpadBtn(
              icon: Icons.keyboard_arrow_up,
              size: btnSize,
              onTapDown: onUp,
            ),
          ),
          // DOWN: Dropdown platform
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildDpadBtn(
              icon: Icons.keyboard_arrow_down,
              size: btnSize,
              onTapDown: onDown,
            ),
          ),
          // LEFT
          Align(
            alignment: Alignment.centerLeft,
            child: _buildDpadBtn(
              icon: Icons.keyboard_arrow_left,
              size: btnSize,
              onTapDown: onLeftDown,
              onTapUp: onLeftUp,
            ),
          ),
          // RIGHT
          Align(
            alignment: Alignment.centerRight,
            child: _buildDpadBtn(
              icon: Icons.keyboard_arrow_right,
              size: btnSize,
              onTapDown: onRightDown,
              onTapUp: onRightUp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDpadBtn({
    required IconData icon,
    required double size,
    VoidCallback? onTapDown,
    VoidCallback? onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown?.call(),
      onTapUp: (_) => onTapUp?.call(),
      onTapCancel: () => onTapUp?.call(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white70, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
          ],
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
