import 'package:flutter/material.dart';
import 'game_wrapper.dart'; 

// =============================================================================
// THEME DEFINITIONS
// =============================================================================
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

const Color primaryThemeColor = dfDeepTeal;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;
const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);
const double cardBorderRadius = 16.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
  const mitigationFactor = 0.9;
  return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
}

class GamesScreen extends StatefulWidget {
  final int? breakSecondsRemaining;
  const GamesScreen({super.key, this.breakSecondsRemaining});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  // Key to access the wrapper state (for time sync)
  final GlobalKey<GameWrapperState> _wrapperKey = GlobalKey<GameWrapperState>();

  @override
  Widget build(BuildContext context) {
    // If breakSecondsRemaining is passed, we wrap the entire Menu in the GameWrapper
    // This ensures the timer shows up on the Menu screen too.
    if (widget.breakSecondsRemaining != null) {
      return GameWrapper(
        key: _wrapperKey,
        isBreakSession: true,
        initialSeconds: widget.breakSecondsRemaining,
        child: _buildMenuContent(context, true),
      );
    } else {
      // Main Menu access (No timer)
      return GameWrapper(
        isBreakSession: false,
        child: _buildMenuContent(context, false),
      );
    }
  }

  Widget _buildMenuContent(BuildContext context, bool isBreakSession) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final proportionalHorizontalPadding = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        // The Wrapper handles the leading button, so we hide it here to avoid duplicates
        automaticallyImplyLeading: false, 
        title: Text(
          'Games',
          style: TextStyle(
            fontSize: adaptiveFontSize(context, 0.045),
            fontWeight: FontWeight.bold,
            color: primaryTextDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: proportionalHorizontalPadding,
            right: proportionalHorizontalPadding,
            top: screenHeight * 0.02,
            bottom: screenHeight * 0.03,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mini Games',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.055),
                  fontWeight: FontWeight.w800,
                  color: primaryTextDark,
                ),
              ),
              Text(
                'Train your attention and focus',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.035),
                  color: secondaryTextGrey,
                ),
              ),
              SizedBox(height: screenHeight * 0.03),

              _buildGameCard(
                context: context,
                title: 'Riddles & Logic',
                subtitle: 'Test your quick thinking and logic skills',
                icon: Icons.lightbulb_outline_rounded,
                accentColor: primaryThemeColor,
                onTap: () => _handleGameNavigation(context, const RiddleGamePlaceholder(), isBreakSession),
              ),

              _buildGameCard(
                context: context,
                title: 'Math Challenges',
                subtitle: 'Quickly solve problems to boost focus',
                icon: Icons.calculate_outlined,
                accentColor: accentThemeColor,
                onTap: () => _handleGameNavigation(context, const MathGamePlaceholder(), isBreakSession),
              ),

              _buildInsightCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // === NAVIGATION & SYNC LOGIC ===
  Future<void> _handleGameNavigation(BuildContext context, Widget gameWidget, bool isBreakSession) async {
    int? currentTime;
    
    // 1. If in break, get current time and PAUSE menu timer
    if (isBreakSession && _wrapperKey.currentState != null) {
      currentTime = _wrapperKey.currentState!.getSecondsRemaining();
      _wrapperKey.currentState!.pauseTimer();
    }

    // 2. Navigate to the specific game
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameWrapper(
          isBreakSession: isBreakSession,
          initialSeconds: currentTime, // Pass exact current time
          child: gameWidget,
        ),
      ),
    );

    // 3. User returned or time ran out
    if (isBreakSession && _wrapperKey.currentState != null) {
      if (result is int) {
        // Returned with remaining time -> Update and Resume
        if (result <= 0) {
           // Time ran out in sub-game
           Navigator.of(context).pop(0); 
        } else {
           _wrapperKey.currentState!.updateSeconds(result);
           _wrapperKey.currentState!.resumeTimer();
        }
      } else {
        // Just resumed (e.g. back button) without specific time? assume standard flow
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                Container(
                  width: screenWidth * 0.14,
                  height: screenWidth * 0.14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentColor, accentColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: screenWidth * 0.07, color: Colors.white),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
                      SizedBox(height: screenHeight * 0.005),
                      Text(subtitle, style: TextStyle(fontSize: adaptiveFontSize(context, 0.033), color: secondaryTextGrey, height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: screenWidth * 0.045, color: secondaryTextGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(top: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentThemeColor.withOpacity(0.15), lightestAccentColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: accentThemeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: accentThemeColor, size: adaptiveFontSize(context, 0.06)),
              SizedBox(width: screenWidth * 0.02),
              Text('Why Warm-Up?', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildInsightPoint(context, Icons.speed_rounded, 'Mental Activation', 'Prepares your brain for focused work'),
          _buildInsightPoint(context, Icons.compare_arrows_rounded, 'Quick Transition', 'Smooth shifts into deep focus modes'),
          _buildInsightPoint(context, Icons.star_half_rounded, 'Optional Enhancement', 'Use when you need extra mental clarity'),
        ],
      ),
    );
  }

  Widget _buildInsightPoint(BuildContext context, IconData icon, String boldText, String lightText) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentThemeColor, size: adaptiveFontSize(context, 0.045)),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: adaptiveFontSize(context, 0.035), color: primaryTextDark, height: 1.4),
                children: [
                  TextSpan(text: '$boldText: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: lightText, style: TextStyle(fontWeight: FontWeight.normal, color: secondaryTextGrey)),
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
// PLACEHOLDERS 
// =============================================================================
class MathGamePlaceholder extends StatelessWidget {
  const MathGamePlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Container(color: Colors.white, child: const Center(child: Text("Math Game UI Goes Here\n(Coming Soon)", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: dfDeepTeal, decoration: TextDecoration.none))));
}

class RiddleGamePlaceholder extends StatelessWidget {
  const RiddleGamePlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Container(color: Colors.white, child: const Center(child: Text("Riddle Game UI Goes Here\n(Coming Soon)", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: dfDeepTeal, decoration: TextDecoration.none))));
}