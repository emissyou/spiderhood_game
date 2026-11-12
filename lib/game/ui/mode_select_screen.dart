import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import '../services/story_progress_service.dart';
import 'loading_screen.dart';
import 'moonlit_rooftop_screen.dart';
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
    // Load checkpoint
    StoryProgressService.instance.loadProgress().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showStoryOptionsDialog(BuildContext context) {
    final story = StoryProgressService.instance;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Center(
          child: SingleChildScrollView(
            child: PixelContainer(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              backgroundColor: const Color(0xFF0F172A),
              borderColor: const Color(0xFF00F0FF),
              borderWidth: 2.5,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CHOOSE STORY PART',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CURRENT PROGRESS: ${story.currentPartTitle}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Choice 1: Part 1
                    _buildPartSelectionTile(
                      partNumber: 1,
                      title: 'PART 1: THE ABANDONED WAREHOUSE',
                      subtitle: 'Docklands infiltration, syndicate sentries & Viper Warlord boss',
                      accentColor: const Color(0xFF10B981),
                      isActive: story.currentPart == 1,
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        AudioManager.instance.resumeBgmIfSuspended();
                        await story.saveProgress(1);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Choice 2: Part 2
                    _buildPartSelectionTile(
                      partNumber: 2,
                      title: 'PART 2: MOONLIT ROOFTOP CITYSCAPE',
                      subtitle: 'Midnight skyline, rooftop marksman minion & city platforming',
                      accentColor: const Color(0xFF38BDF8),
                      isActive: story.currentPart == 2,
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        AudioManager.instance.resumeBgmIfSuspended();
                        await story.saveProgress(2);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MoonlitRooftopScreen()),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PixelButton(
                          text: 'RESET STORY ↺',
                          color: const Color(0xFFEF4444),
                          textColor: Colors.white,
                          fontSize: 10,
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            AudioManager.instance.resumeBgmIfSuspended();
                            await story.resetStory();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        PixelButton(
                          text: 'CLOSE ◀',
                          color: Colors.white24,
                          textColor: Colors.white,
                          fontSize: 10,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartSelectionTile({
    required int partNumber,
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? accentColor : Colors.white24,
            width: isActive ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? accentColor.withValues(alpha: 0.25) : Colors.black45,
              offset: const Offset(2, 2),
              blurRadius: isActive ? 6 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 1.5),
              ),
              child: Text(
                '$partNumber',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isActive ? accentColor : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: accentColor, size: 24),
          ],
        ),
      ),
    );
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

                            final isPart2 = StoryProgressService.instance.currentPart == 2;

                            final storyCard = _buildModeCard(
                              context: context,
                              title: 'STORY MODE',
                              badgeText: isPart2 ? 'PART 2: ROOFTOPS' : 'CHAPTER 1: THE VIPERS',
                              badgeColor: isPart2 ? const Color(0xFF38BDF8) : PixelColors.yellow,
                              badgeTextColor: Colors.black,
                              icon: Icons.menu_book,
                              accentColor: const Color(0xFF00F0FF),
                              description: isPart2
                                  ? 'The Viper Warlord fled across Manhattan! Scale the skyscrapers under the moonlight and neutralize the armed marksman!'
                                  : 'Stop The Vipers from constructing Vulture\'s catastrophic weapon. Infiltrate clandestine bases starting with the Abandoned Factory!',
                              features: isPart2
                                  ? [
                                      '• Chapter 1: The Viper Syndicate',
                                      '• Checkpoint: Moonlit Rooftop Cityscape',
                                      '• Marksman Minion & Skyline Combat',
                                    ]
                                  : [
                                      '• Chapter 1: The Viper Syndicate',
                                      '• Bank Heist Mystery & Device Map',
                                      '• Scenario 1: The Abandoned Factory',
                                    ],
                              buttonText: isPart2 ? 'CONTINUE (PART 2) ▶' : 'PLAY STORY MODE ▶',
                              buttonColor: const Color(0xFF00F0FF),
                              buttonTextColor: Colors.black,
                              onPressed: () {
                                AudioManager.instance.resumeBgmIfSuspended();
                                if (isPart2) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const MoonlitRooftopScreen(),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const StoryIntroScreen(),
                                    ),
                                  );
                                }
                              },
                              extraWidget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PixelButton(
                                    text: isPart2 ? 'STORY OPTIONS / RESTART ⚙' : 'STORY OPTIONS ⚙',
                                    color: Colors.white12,
                                    textColor: Colors.white,
                                    fontSize: 10,
                                    isFullWidth: true,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    onPressed: () => _showStoryOptionsDialog(context),
                                  ),
                                  const SizedBox(height: 6),
                                  PixelButton(
                                    text: 'CHOOSE PART (1 OR 2) ❖',
                                    color: const Color(0xFF38BDF8),
                                    textColor: Colors.black,
                                    fontSize: 10,
                                    isFullWidth: true,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    onPressed: () => _showStoryOptionsDialog(context),
                                  ),
                                ],
                              ),
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
    Widget? extraWidget,
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
          if (extraWidget != null) ...[
            const SizedBox(height: 8),
            extraWidget,
          ],
        ],
      ),
    );
  }
}
