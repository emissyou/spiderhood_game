import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/ui/pixel_widgets.dart';

/// Interactive HUD and touch controls for Story Quest 1: The Abandoned Warehouse.
class StoryQuestHud extends StatefulWidget {
  final WarehouseGame game;

  const StoryQuestHud({super.key, required this.game});

  @override
  State<StoryQuestHud> createState() => _StoryQuestHudState();
}

class _StoryQuestHudState extends State<StoryQuestHud> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Continuous 30fps HUD state refresh to update boss HP, quest progress, cutscene banner, and buttons
    _updateTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.instance;
    final game = widget.game;

    return SafeArea(
      child: Stack(
        children: [
          // Top Center: Viper Boss Health Bar
          if (game.boss.isMounted && game.boss.bossState != BossState.escaped && game.hasPlayerEngaged)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: const Color(0xFF0F172A),
                  borderColor: game.boss.hasTriggeredEnrage ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                  borderWidth: 2.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: game.boss.hasTriggeredEnrage ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            game.boss.hasTriggeredEnrage
                                ? 'VIPER WARLORD [ENRAGED 2X CRIT]'
                                : (game.boss.bossState == BossState.waitingRightInvulnerable
                                    ? 'VIPER WARLORD [SHIELDED]'
                                    : 'VIPER WARLORD'),
                            style: TextStyle(
                              color: game.boss.hasTriggeredEnrage ? const Color(0xFFEF4444) : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 200,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (game.boss.health / ViperBoss.maxHp).clamp(0.0, 1.0),
                          child: Container(
                            color: game.boss.hasTriggeredEnrage
                                ? const Color(0xFFEF4444)
                                : (game.boss.health > ViperBoss.maxHp * 0.5 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Cutscene dialogue & guidance banner
          if (game.cutsceneBanner != null)
            Positioned(
              top: 75,
              left: 32,
              right: 32,
              child: Center(
                child: PixelContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  backgroundColor: const Color(0xFF1E1E2F).withValues(alpha: 0.95),
                  borderColor: const Color(0xFF00F0FF),
                  borderWidth: 2.5,
                  child: Text(
                    game.cutsceneBanner!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),

          // Top Left: Story Quest Objectives Tracker
          Positioned(
            top: 14,
            left: 16,
            child: PixelContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: const Color(0xFF131724),
              borderColor: const Color(0xFF10B981),
              borderWidth: 2.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'LOCATION 1: ABANDONED FACTORY',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildObjectiveRow(
                    text: 'Recover Tech Cores: ${game.collectedCores}/${WarehouseGame.targetCores}',
                    isDone: game.collectedCores >= WarehouseGame.targetCores,
                  ),
                  const SizedBox(height: 3),
                  _buildObjectiveRow(
                    text: 'Neutralize Viper Sentries: ${game.defeatedGuards}/${WarehouseGame.targetGuards}',
                    isDone: game.defeatedGuards >= WarehouseGame.targetGuards,
                  ),
                  const SizedBox(height: 3),
                  _buildObjectiveRow(
                    text: 'Infiltrate Deep Sector Terminal',
                    isDone: game.terminalReached,
                  ),
                  if (game.boss.hasTriggeredEscape) ...[
                    const SizedBox(height: 3),
                    _buildObjectiveRow(
                      text: 'Pursue Warlord: ${game.player.position.x.toInt().clamp(0, 1434)}/1434m',
                      isDone: game.hasTriggeredEscapeScenario,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Top Right: Sound Mute & Menu
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
                    if (game.onExitToMenu != null) {
                      game.onExitToMenu!();
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
                          'MAP',
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

          // Floating Arrow Button leading to boss escape exit
          if (game.boss.hasTriggeredEscape && !game.hasTriggeredEscapeScenario)
            Positioned(
              top: 72,
              right: 16,
              child: _buildBossEscapeArrowButton(game),
            ),

          // Controls (Bottom Left: Move Pad - active with subtle opacity during cutscene)
          Positioned(
            bottom: 24,
            left: 20,
            child: Opacity(
              opacity: game.isEntranceCutscene ? 0.45 : 1.0,
              child: Row(
                children: [
                  _buildControlButton(
                    icon: Icons.arrow_back,
                    onDown: () => game.startMoveLeft(),
                    onUp: () => game.stopMove(),
                  ),
                  const SizedBox(width: 14),
                  _buildControlButton(
                    icon: Icons.arrow_forward,
                    onDown: () => game.startMoveRight(),
                    onUp: () => game.stopMove(),
                  ),
                ],
              ),
            ),
          ),

          // Controls (Bottom Right: Actions - active with subtle opacity during cutscene)
          Positioned(
            bottom: 24,
            right: 16,
            child: Opacity(
              opacity: game.isEntranceCutscene ? 0.45 : 1.0,
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
                    subtitle: 'WEB SHOT',
                    color: const Color(0xFF7209B7),
                    onTap: () => game.useSkill(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    label: 'SWING',
                    subtitle: 'WEB',
                    color: const Color(0xFF028090),
                    onTap: () => game.shootWebAhead(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    label: 'JUMP',
                    subtitle: 'LEAP',
                    color: const Color(0xFF003049),
                    onTap: () => game.jump(),
                  ),
                ],
              ),
            ),
          ),

          // Mission Complete Modal Splash
          if (game.isMissionComplete)
            Center(
              child: PixelContainer(
                backgroundColor: const Color(0xFF131A2E),
                borderColor: const Color(0xFF10B981),
                borderWidth: 3.5,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: PixelColors.yellow, size: 44),
                    const SizedBox(height: 10),
                    const Text(
                      'LOCATION 1 SECURED!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All 3 Viper tech cores recovered!\n'
                      'Vulture\'s weapon data has been decoded on the city map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    PixelButton(
                      text: 'RETURN TO VIPER MAP ▶',
                      color: PixelColors.green,
                      textColor: Colors.black,
                      fontSize: 12,
                      onPressed: () {
                        if (game.onMissionComplete != null) {
                          game.onMissionComplete!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildObjectiveRow({required String text, required bool isDone}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? const Color(0xFF10B981) : Colors.white38,
          size: 13,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isDone ? const Color(0xFF10B981) : Colors.white70,
            fontSize: 10,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: () => onUp(),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBossEscapeArrowButton(WarehouseGame game) {
    return GestureDetector(
      onTap: () => game.pursueBossToExit(),
      child: PixelContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: const Color(0xFF1E1E2F).withValues(alpha: 0.95),
        borderColor: const Color(0xFFF59E0B),
        borderWidth: 2.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'PURSUE BOSS ▶▶',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'EXIT: 70% MAP (${game.player.position.x.toInt().clamp(0, 1434)}/1434m)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFF59E0B),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.black,
                size: 18,
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
