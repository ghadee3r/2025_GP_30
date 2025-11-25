import 'package:flutter/material.dart';

// =============================================================================
// THEME DEFINITIONS - Matching SetSession
// =============================================================================

// Primary color palette
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

// Primary theme colors
const Color primaryThemeColor = dfDeepTeal;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;

// Background colors
const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);

// Text colors
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);

// Standard border radius for cards
const double cardBorderRadius = 16.0;

// Standard shadow for elevated cards
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

// Adaptive font sizing
double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScaleFactor = MediaQuery.of(context).textScaleFactor;
  const mitigationFactor = 0.9;
  return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
}

// =============================================================================

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  // Build game card
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
                // Icon container
                Container(
                  width: screenWidth * 0.14,
                  height: screenWidth * 0.14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor,
                        accentColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: screenWidth * 0.07,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: adaptiveFontSize(context, 0.045),
                          fontWeight: FontWeight.bold,
                          color: primaryTextDark,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: adaptiveFontSize(context, 0.033),
                          color: secondaryTextGrey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: screenWidth * 0.045,
                  color: secondaryTextGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build insight card
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
          colors: [
            accentThemeColor.withOpacity(0.15),
            lightestAccentColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: accentThemeColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                color: accentThemeColor,
                size: adaptiveFontSize(context, 0.06),
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Why Warm-Up?',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.045),
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),

          // Insights
          _buildInsightPoint(
            context,
            Icons.speed_rounded,
            'Mental Activation',
            'Prepares your brain for focused work',
          ),
          _buildInsightPoint(
            context,
            Icons.compare_arrows_rounded,
            'Quick Transition',
            'Smooth shifts into deep focus modes',
          ),
          _buildInsightPoint(
            context,
            Icons.star_half_rounded,
            'Optional Enhancement',
            'Use when you need extra mental clarity',
          ),
        ],
      ),
    );
  }

  // Build insight point
  Widget _buildInsightPoint(
    BuildContext context,
    IconData icon,
    String boldText,
    String lightText,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accentThemeColor,
            size: adaptiveFontSize(context, 0.045),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.035),
                  color: primaryTextDark,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$boldText: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: lightText,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: secondaryTextGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final proportionalHorizontalPadding = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              // Page title and subtitle
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

              // Game cards
              _buildGameCard(
                context: context,
                title: 'Riddles & Logic',
                subtitle: 'Test your quick thinking and logic skills',
                icon: Icons.lightbulb_outline_rounded,
                accentColor: primaryThemeColor,
                onTap: () {
                  // Navigate to riddles game
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Riddles & Logic game coming soon!'),
                      backgroundColor: accentThemeColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              _buildGameCard(
                context: context,
                title: 'Math Challenges',
                subtitle: 'Quickly solve problems to boost focus',
                icon: Icons.calculate_outlined,
                accentColor: accentThemeColor,
                onTap: () {
                  // Navigate to math game
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Math Challenges coming soon!'),
                      backgroundColor: accentThemeColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              // Insight card
              _buildInsightCard(context),
            ],
          ),
        ),
      ),
    );
  }
}