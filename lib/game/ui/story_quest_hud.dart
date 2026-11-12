import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spideyhood/game/actors/enemies/viper_boss.dart';
import 'package:spideyhood/game/actors/enemies/viper_guard.dart';
import 'package:spideyhood/game/actors/player/spidey.dart';
import 'package:spideyhood/game/services/audio_manager.dart';
import 'package:spideyhood/game/services/story_progress_service.dart';
import 'package:spideyhood/game/story/warehouse_game.dart';
import 'package:spideyhood/game/ui/moonlit_rooftop_screen.dart';
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
  bool _isMenuOpen = false;

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
                            color: const Color(0xFFEF4444),
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

          // Top Left: Player Status (HP & Fluid) & Story Quest Objectives Tracker
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
                  // Row 1: Player HP & Web Fluid in 1 row (slightly bigger)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPlayerHealthRow(game.player),
                      const SizedBox(width: 14),
                      _buildPlayerWebFluidRow(game.player),
                      if (game.player.shieldTimer > 0) ...[
                        const SizedBox(width: 8),
                        _buildPlayerShieldBadge(game.player),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 7),
                  // Row 2: Location Header
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
                    text: 'Recover Compound-V: ${game.collectedCores}/${WarehouseGame.targetCores}',
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
                      'All 3 Compound-V vials recovered!\n'
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
                          : const Color(0xFF00F0FF),
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
                              'STORY MODE • PART 1: ABANDONED WAREHOUSE',
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
                                color: const Color(0xFF00F0FF),
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
                              text: 'GO TO PART 2 (ROOFTOPS) ▶',
                              color: const Color(0xFF38BDF8),
                              textColor: Colors.black,
                              fontSize: 11,
                              onPressed: () async {
                                AudioManager.instance.resumeBgmIfSuspended();
                                await StoryProgressService.instance.saveProgress(2);
                                if (context.mounted) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const MoonlitRooftopScreen()),
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

  Widget _buildPlayerHealthRow(Spidey player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'HP: ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        for (int i = 0; i < Spidey.maxHealth; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2.5),
            child: Icon(
              i < player.health ? Icons.favorite : Icons.favorite_border,
              color: i < player.health ? const Color(0xFFEF4444) : Colors.white24,
              size: 16,
            ),
          ),
        const SizedBox(width: 5),
        Text(
          '${player.health}/${Spidey.maxHealth}',
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        if (player.activeGodMode) ...[
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
    );
  }

  Widget _buildPlayerWebFluidRow(Spidey player) {
    final fluidInt = player.webFluid.clamp(0, 10).toInt();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.stream, color: Color(0xFF38BDF8), size: 14),
        const SizedBox(width: 4),
        const Text(
          'FLUID: ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        Container(
          width: 70,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (player.webFluid / Spidey.maxWebFluid).clamp(0.0, 1.0),
            child: Container(
              color: const Color(0xFF38BDF8),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$fluidInt/10',
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerShieldBadge(Spidey player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFACC15), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield, color: Color(0xFFFACC15), size: 11),
          const SizedBox(width: 4),
          Text(
            'SHIELD: ${player.shieldTimer.toStringAsFixed(1)}s',
            style: const TextStyle(
              color: Color(0xFFFACC15),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossEscapeArrowButton(WarehouseGame game) {
    final aliveMinions = game.world.children.whereType<ViperGuard>().where((g) => !g.isDefeated).length;
    final canPursue = aliveMinions == 0;
    final borderColor = canPursue ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final accentColor = canPursue ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () => game.pursueBossToExit(),
      child: PixelContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: const Color(0xFF1E1E2F).withValues(alpha: 0.95),
        borderColor: borderColor,
        borderWidth: 2.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      canPursue ? Icons.warning_amber_rounded : Icons.shield_outlined,
                      color: accentColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      canPursue ? 'PURSUE BOSS ▶▶' : 'CLEAR SENTRIES ($aliveMinions)',
                      style: TextStyle(
                        color: accentColor,
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
                  canPursue
                      ? 'EXIT: 70% MAP (${game.player.position.x.toInt().clamp(0, 1434)}/1434m)'
                      : 'DEFEAT ALL SENTRIES TO PURSUE!',
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
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: accentColor,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                canPursue ? Icons.arrow_forward : Icons.lock_clock,
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
