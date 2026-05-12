import 'package:flutter/material.dart';
import 'game_wrapper.dart'; 
import 'breathing_screen.dart'; 
import 'pattern_screen.dart'; 
import 'reflex_screen.dart';

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color cardBackground = Color(0xFFFFFFFF);
const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.04),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ];

double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
  const mitigationFactor = 0.9;
  return baseSize / (1.0 + (textScale - 1.0) * mitigationFactor);
}

class GamesScreen extends StatefulWidget {
  final int? breakSecondsRemaining;
  const GamesScreen({super.key, this.breakSecondsRemaining});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final GlobalKey<GameWrapperState> _wrapperKey = GlobalKey<GameWrapperState>();

  @override
  Widget build(BuildContext context) {
    if (widget.breakSecondsRemaining != null) {
      // SCENARIO 1: WE ARE IN A BREAK
      // Wrap the menu in GameWrapper so the Timer and 'X' close button show up.
      return GameWrapper(
        key: _wrapperKey,
        isBreakSession: true,
        showBackButton: true, 
        initialSeconds: widget.breakSecondsRemaining,
        child: _buildMenuContent(context, true),
      );
    } else {
      // SCENARIO 2: NORMAL MAIN MENU
      // Do NOT use GameWrapper at all. This makes it physically impossible 
      // for the back arrow or any wrapper UI to appear on the main tab!
      return _buildMenuContent(context, false);
    }
  }

  Widget _buildMenuContent(BuildContext context, bool isBreakSession) {
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = 24.0;

    // Extra top padding if the 'X' close button is showing, so they don't overlap
    final topPadding = isBreakSession ? screenHeight * 0.12 : 40.0;

    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, 
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)],
              )
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: topPadding, 
                bottom: screenHeight * 0.15, // Padding for bottom nav bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mini Games',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.normal,
                      color: dfNavyIndigo,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Quick mental resets for peak focus.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: secondaryTextGrey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  _buildGameCard(
                    context: context,
                    title: 'Pattern Matcher',
                    subtitle: 'Challenge your numeric memory',
                    icon: Icons.grid_view_rounded,
                    accentColor: customModeColor, 
                    onTap: () => _handleGameNavigation(context, const PatternScreen(), isBreakSession),
                  ),
                  _buildGameCard(
                    context: context,
                    title: 'Reflex Popper',
                    subtitle: 'Test your rhythm and speed',
                    icon: Icons.ads_click_rounded,
                    accentColor: dfTealCyan, 
                    onTap: () => _handleGameNavigation(context, const ReflexScreen(), isBreakSession),
                  ),
                  _buildGameCard(
                    context: context,
                    title: 'Mindful Breathing',
                    subtitle: 'Box breathing to lower stress',
                    icon: Icons.air_rounded,
                    accentColor: const Color(0xFF4FC3F7), 
                    onTap: () => _handleGameNavigation(context, const BreathingScreen(), isBreakSession),
                  ),

                  SizedBox(height: screenHeight * 0.02),
                  _buildInsightCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGameNavigation(BuildContext context, Widget gameWidget, bool isBreakSession) async {
    int? currentTime;
    
    if (isBreakSession && _wrapperKey.currentState != null) {
      currentTime = _wrapperKey.currentState!.getSecondsRemaining();
      _wrapperKey.currentState!.pauseTimer();
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameWrapper(
          isBreakSession: isBreakSession,
          initialSeconds: currentTime, 
          // Always show the back/close button INSIDE the actual games
          showBackButton: true, 
          child: gameWidget,
        ),
      ),
    );

    if (isBreakSession && _wrapperKey.currentState != null) {
      if (result is int) {
        if (result <= 0) {
           Navigator.of(context).pop(0); 
        } else {
           _wrapperKey.currentState!.updateSeconds(result);
           _wrapperKey.currentState!.resumeTimer();
        }
      } else {
        _wrapperKey.currentState!.resumeTimer();
      }
    }
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return _InteractiveCard(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6), 
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: subtleShadow,
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.14,
              height: screenWidth * 0.14,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: screenWidth * 0.07, color: accentColor),
            ),
            SizedBox(width: screenWidth * 0.05),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontSize: adaptiveFontSize(context, 0.045), 
                      fontWeight: FontWeight.bold, 
                      color: dfNavyIndigo
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      fontSize: adaptiveFontSize(context, 0.033), 
                      color: secondaryTextGrey, 
                      height: 1.3
                    )
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: screenWidth * 0.04, color: secondaryTextGrey.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(top: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: customModeColor.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: customModeColor.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: customModeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.psychology_alt_rounded, color: customModeColor, size: adaptiveFontSize(context, 0.05)),
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'Why Warm-Up?', 
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.045), 
                  fontWeight: FontWeight.bold, 
                  color: dfNavyIndigo
                )
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildInsightPoint(context, Icons.speed_rounded, 'Activation', 'Prepares your brain for focused work'),
          _buildInsightPoint(context, Icons.compare_arrows_rounded, 'Shift', 'Smooth shifts into focus modes'),
          _buildInsightPoint(context, Icons.star_half_rounded, 'Enhancement', 'Extra mental clarity when needed'),
        ],
      ),
    );
  }

  Widget _buildInsightPoint(BuildContext context, IconData icon, String boldText, String lightText) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: customModeColor.withOpacity(0.7), size: adaptiveFontSize(context, 0.045)),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: adaptiveFontSize(context, 0.035), color: dfNavyIndigo, height: 1.4),
                children: [
                  TextSpan(text: '$boldText: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: lightText, style: TextStyle(fontWeight: FontWeight.w500, color: secondaryTextGrey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REUSABLE INTERACTIVE SQUISH COMPONENT
// =============================================================================
class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractiveCard({required this.child, required this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}