import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import '../spidey_game.dart';

/// Comic overlay HUD with responsive touch controls, drag-to-aim web swinging, and audio toggle.
class ComicHud extends StatefulWidget {
  final SpideyGame game;

  const ComicHud({super.key, required this.game});

  @override
  State<ComicHud> createState() => _ComicHudState();
}

class _ComicHudState extends State<ComicHud> {
  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.instance;
    return SafeArea(
      child: Stack(
        children: [
          // Top Status Banner
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Spidey Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'CHARACTER: SPIDEY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.1,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // Stage Info & Menu Exit Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white30, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, offset: Offset(2, 2)),
                        ],
                      ),
                      child: const Text(
                        'STAGE: SURVIVAL LVL 1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sound Mute Toggle
                    InkWell(
                      onTap: () {
                        setState(() {
                          audio.toggleMute();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: audio.isMuted ? Colors.grey.shade800 : const Color(0xFF1D3557),
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
                        if (widget.game.onExitToMenu != null) {
                          widget.game.onExitToMenu!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
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
                            Icon(Icons.menu, color: Colors.white, size: 16),
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
              ],
            ),
          ),

          // Desktop Keyboard Help Legend (Top Center)
          Positioned(
            top: 66,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Text(
                  '🖱 Click to Web-Swing • ⌨ [A / D] Move • [Space] Jump • [J / Z] Punch • [L / C] Web Shot',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Mobile Touch Controls: Left / Right Pad (Bottom Left)
          Positioned(
            bottom: 24,
            left: 20,
            child: Row(
              children: [
                _buildControlButton(
                  icon: Icons.arrow_back,
                  onDown: () => widget.game.startMoveLeft(),
                  onUp: () => widget.game.stopMove(),
                  bgColor: const Color(0xFF1E1E24),
                ),
                const SizedBox(width: 14),
                _buildControlButton(
                  icon: Icons.arrow_forward,
                  onDown: () => widget.game.startMoveRight(),
                  onUp: () => widget.game.stopMove(),
                  bgColor: const Color(0xFF1E1E24),
                ),
              ],
            ),
          ),

          // Mobile Touch Controls: Punch, Drag-to-Swing & Jump (Bottom Right)
          Positioned(
            bottom: 24,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PUNCH Action Button (18 Damage)
                _buildActionButton(
                  label: 'PUNCH',
                  subtitle: '18 DMG',
                  color: const Color(0xFFD62828),
                  onTap: () => widget.game.punch(),
                ),
                const SizedBox(width: 8),
                // KICK Action Button (32 Damage)
                _buildActionButton(
                  label: 'KICK',
                  subtitle: '32 DMG',
                  color: const Color(0xFFF77F00),
                  onTap: () => widget.game.kick(),
                ),
                const SizedBox(width: 8),
                // SKILL 1 Action Button (Web Shot Ammo Blast)
                _buildActionButton(
                  label: 'SKILL',
                  subtitle: 'WEB SHOT',
                  color: const Color(0xFF7209B7),
                  onTap: () => widget.game.useSkill(),
                ),
                const SizedBox(width: 8),
                // WEB SWING Action Button (Drag anywhere to aim & let go!)
                _SwingDragButton(game: widget.game),
                const SizedBox(width: 8),
                // JUMP Action Button (Double Jump to Crawl, Jump to Release)
                _buildActionButton(
                  label: 'JUMP',
                  subtitle: 'LEAP',
                  color: const Color(0xFF003049),
                  onTap: () => widget.game.jump(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: () => onUp(),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Drag-to-Aim Web Swing Button
class _SwingDragButton extends StatefulWidget {
  final SpideyGame game;

  const _SwingDragButton({required this.game});

  @override
  State<_SwingDragButton> createState() => _SwingDragButtonState();
}

class _SwingDragButtonState extends State<_SwingDragButton> {
  Offset _dragDelta = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        widget.game.shootWebAhead();
      },
      onTapUp: (_) {
        widget.game.releaseWeb();
      },
      onTapCancel: () {
        widget.game.releaseWeb();
      },
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
          _dragDelta = Offset.zero;
        });
        widget.game.shootWebAhead();
      },
      onPanUpdate: (details) {
        setState(() {
          _dragDelta += details.delta;
        });
        if (_dragDelta.distance > 15) {
          final aimDir = Vector2(
            _dragDelta.dx,
            -_dragDelta.dy.abs().clamp(20.0, 300.0),
          );
          widget.game.shootWebInDirection(aimDir);
        }
      },
      onPanEnd: (details) {
        widget.game.releaseWeb();
        setState(() {
          _isDragging = false;
          _dragDelta = Offset.zero;
        });
      },
      onPanCancel: () {
        widget.game.releaseWeb();
        setState(() {
          _isDragging = false;
          _dragDelta = Offset.zero;
        });
      },
      child: Transform.translate(
        offset: Offset(
          _dragDelta.dx.clamp(-16.0, 16.0),
          _dragDelta.dy.clamp(-16.0, 16.0),
        ),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: _isDragging ? const Color(0xFF0077B6) : const Color(0xFF00B4D8),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isDragging ? Colors.white : Colors.white30,
              width: _isDragging ? 3 : 2,
            ),
            boxShadow: _isDragging
                ? [
                    const BoxShadow(
                      color: Color(0xFF00B4D8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SWING',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'DRAG AIM',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
