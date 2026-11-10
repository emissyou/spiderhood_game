import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/audio_manager.dart';
import 'mode_select_screen.dart';
import 'pixel_widgets.dart';

/// Level selection screen for Survival Mode featuring 3 stages.
/// Stage 1 contains the active developed game (Sidewalk Patrol).
class SurvivalLevelScreen extends StatelessWidget {
  const SurvivalLevelScreen({super.key});

  void _launchLevel1(BuildContext context) {
    AudioManager.instance.resumeBgmIfSuspended();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SpideyhoodGameScreen(),
      ),
    );
  }

  void _showLockedDialog(BuildContext context, String levelName, String requirement) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: PixelContainer(
              backgroundColor: const Color(0xFF161A2E),
              borderColor: PixelColors.red,
              borderWidth: 3,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: PixelColors.yellow, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    levelName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This survival stage is currently locked.\n$requirement to unlock this district!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PixelButton(
                    text: 'UNDERSTOOD',
                    color: PixelColors.red,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Stack(
        children: [
          // Ambient Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/environment/new_york_morning.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PixelButton(
                        text: '◀ MODES',
                        color: Colors.white12,
                        textColor: Colors.white,
                        fontSize: 11,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
                          );
                        },
                      ),
                      const PixelBadge(
                        text: 'SURVIVAL MODE: SELECT LEVEL',
                        color: PixelColors.red,
                        textColor: Colors.white,
                        icon: Icons.shield,
                      ),
                      const SizedBox(width: 70), // Balance
                    ],
                  ),
                ),

                // 3 Levels Cards in Scrollable Row / Column
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 700;

                            final level1Card = _buildLevelCard(
                              context: context,
                              levelNumber: 'LEVEL 1',
                              title: 'SIDEWALK PATROL',
                              statusBadge: 'UNLOCKED',
                              badgeColor: PixelColors.green,
                              badgeTextColor: Colors.black,
                              isUnlocked: true,
                              accentColor: PixelColors.yellow,
                              location: 'Manhattan 5th Ave Sidewalk',
                              threats: 'Sidewalk Thugs & Speeding Taxis',
                              description:
                                  'Patrol the sunny morning sidewalks! Defeat thugs, dodge taxi traffic, and protect citizens.',
                              buttonText: '▶ START PATROL',
                              buttonColor: PixelColors.green,
                              buttonTextColor: Colors.black,
                              onPressed: () => _launchLevel1(context),
                            );

                            final level2Card = _buildLevelCard(
                              context: context,
                              levelNumber: 'LEVEL 2',
                              title: 'ROOFTOP SHOWDOWN',
                              statusBadge: 'LOCKED',
                              badgeColor: Colors.grey.shade700,
                              isUnlocked: false,
                              accentColor: const Color(0xFF457B9D),
                              location: 'Queens High-Rise Rooftops',
                              threats: 'Rooftop Snipers & Aerial Gaps',
                              description:
                                  'Web-sling across tall skyscrapers. Narrow perches and lethal drop-offs test your air control.',
                              buttonText: '🔒 LOCKED',
                              buttonColor: Colors.grey.shade800,
                              onPressed: () => _showLockedDialog(
                                context,
                                'Level 2: Rooftop Showdown',
                                'Clear Level 1 with 1,000+ points',
                              ),
                            );

                            final level3Card = _buildLevelCard(
                              context: context,
                              levelNumber: 'LEVEL 3',
                              title: 'MIDTOWN MAYHEM',
                              statusBadge: 'LOCKED',
                              badgeColor: Colors.grey.shade700,
                              isUnlocked: false,
                              accentColor: const Color(0xFFE63946),
                              location: 'Times Square Neon Plaza',
                              threats: 'Syndicate Boss & Glider Swarms',
                              description:
                                  'Intense urban warfare! Survive relentless waves of aerial gliders and armored syndicate bosses.',
                              buttonText: '🔒 LOCKED',
                              buttonColor: Colors.grey.shade800,
                              onPressed: () => _showLockedDialog(
                                context,
                                'Level 3: Midtown Mayhem',
                                'Clear Level 2 with 2,500+ points',
                              ),
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: level1Card),
                                  const SizedBox(width: 16),
                                  Expanded(child: level2Card),
                                  const SizedBox(width: 16),
                                  Expanded(child: level3Card),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  level1Card,
                                  const SizedBox(height: 14),
                                  level2Card,
                                  const SizedBox(height: 14),
                                  level3Card,
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required BuildContext context,
    required String levelNumber,
    required String title,
    required String statusBadge,
    required Color badgeColor,
    Color badgeTextColor = Colors.white,
    required bool isUnlocked,
    required Color accentColor,
    required String location,
    required String threats,
    required String description,
    required String buttonText,
    required Color buttonColor,
    Color buttonTextColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return PixelContainer(
      backgroundColor: isUnlocked ? const Color(0xFF181C30) : const Color(0xFF131522),
      borderColor: isUnlocked ? accentColor : Colors.white24,
      borderWidth: 2.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                levelNumber,
                style: TextStyle(
                  color: isUnlocked ? accentColor : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: PixelBadge(
                  text: statusBadge,
                  color: badgeColor,
                  textColor: badgeTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isUnlocked ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              border: Border.all(
                color: isUnlocked ? Colors.white24 : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 12,
                  color: isUnlocked ? PixelColors.yellow : Colors.white38,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white70 : Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: isUnlocked ? Colors.white70 : Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'THREATS: $threats',
            style: TextStyle(
              color: isUnlocked ? PixelColors.red : Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          PixelButton(
            text: buttonText,
            color: buttonColor,
            textColor: buttonTextColor,
            isFullWidth: true,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(vertical: 10),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
