import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import 'loading_screen.dart';
import 'pixel_widgets.dart';
import 'story_intro_screen.dart';
import 'survival_level_screen.dart';

/// Pixelated Mode Selection Screen (Main Menu) offering Story Mode and Survival Mode.
class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  @override
  void initState() {
    super.initState();
    // Guarantee background music starts playing as soon as Main Menu opens!
    AudioManager.instance.playBgm();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        // User interacted! Immediately wake up any browser-suspended audio context
        AudioManager.instance.resumeBgmIfSuspended();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F111A),
        body: Stack(
        children: [
          // Background ambient art
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
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PixelButton(
                        text: '◀ BACK',
                        color: Colors.white12,
                        textColor: Colors.white,
                        fontSize: 11,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoadingScreen(),
                            ),
                          );
                        },
                      ),
                      const PixelBadge(
                        text: 'SELECT GAME MODE',
                        color: PixelColors.yellow,
                        textColor: Colors.black,
                        icon: Icons.gamepad,
                      ),
                      const SizedBox(width: 70), // Balance back button
                    ],
                  ),
                ),

                // Main 2 Choices Layout
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 580;

                            final storyCard = _buildModeCard(
                              context: context,
                              title: 'STORY MODE',
                              badgeText: 'CHAPTER 1: THE VIPERS',
                              badgeColor: PixelColors.yellow,
                              badgeTextColor: Colors.black,
                              icon: Icons.menu_book,
                              accentColor: const Color(0xFF00F0FF),
                              description:
                                  'Stop The Vipers from constructing Vulture\'s catastrophic weapon. Infiltrate clandestine bases starting with the Abandoned Factory!',
                              features: [
                                '• Chapter 1: The Viper Syndicate',
                                '• Bank Heist Mystery & Device Map',
                                '• Scenario 1: The Abandoned Factory',
                              ],
                              buttonText: 'PLAY STORY MODE ▶',
                              buttonColor: const Color(0xFF00F0FF),
                              buttonTextColor: Colors.black,
                              onPressed: () {
                                AudioManager.instance.resumeBgmIfSuspended();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const StoryIntroScreen(),
                                  ),
                                );
                              },
                            );

                            final survivalCard = _buildModeCard(
                              context: context,
                              title: 'SURVIVAL MODE',
                              badgeText: '3 LEVELS AVAILABLE',
                              badgeColor: PixelColors.green,
                              badgeTextColor: Colors.black,
                              icon: Icons.shield,
                              accentColor: PixelColors.red,
                              description:
                                  'Battle relentless crime waves across Manhattan! Test your web reflexes, combat thugs, dodge cars, and aim for high scores.',
                              features: [
                                '• Level 1: Sidewalk Patrol (Active)',
                                '• Level 2: Rooftop Showdown',
                                '• Level 3: Midtown Mayhem',
                              ],
                              buttonText: 'ENTER SURVIVAL ▶',
                              buttonColor: PixelColors.green,
                              buttonTextColor: Colors.black,
                              onPressed: () {
                                AudioManager.instance.resumeBgmIfSuspended();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const SurvivalLevelScreen(),
                                  ),
                                );
                              },
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: storyCard),
                                  const SizedBox(width: 20),
                                  Expanded(child: survivalCard),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  survivalCard,
                                  const SizedBox(height: 16),
                                  storyCard,
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
    ),
  );
}

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String badgeText,
    required Color badgeColor,
    Color badgeTextColor = Colors.white,
    required IconData icon,
    required Color accentColor,
    required String description,
    required List<String> features,
    required String buttonText,
    required Color buttonColor,
    Color buttonTextColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return PixelContainer(
      backgroundColor: const Color(0xFF161A2B),
      borderColor: accentColor,
      borderWidth: 3,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 28),
              PixelBadge(
                text: badgeText,
                color: badgeColor,
                textColor: badgeTextColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                f,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PixelButton(
            text: buttonText,
            color: buttonColor,
            textColor: buttonTextColor,
            isFullWidth: true,
            fontSize: 13,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
