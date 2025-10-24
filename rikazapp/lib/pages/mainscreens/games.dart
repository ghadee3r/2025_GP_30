import 'package:flutter/material.dart';

// =============================================================================
// REPLICATED THEME DEFINITIONS (Including adaptiveFontSize)
// =============================================================================

// 1. Base Colors
const Color primaryThemePurple = Color(0xFF7A68FF); // Main action color
const Color secondaryThemeBlue = Color(0xFF8DC0FF); // Header end color (soft gradient)
const Color softAccentHighlight = Color(0xFFE9E5FF); // Lightest purple for selections/backgrounds

// 2. Custom Typography Colors
const Color hpDeepBlue = Color.fromARGB(255, 24, 114, 150); // Exact shade for key text
const Color hpThinBlack = Color(0xFF1E1E1E); // Thin black for names

const Color primaryTextDark = Color(0xFF30304D); // Dark text for main headings/titles
const Color secondaryTextGrey = Color(0xFF8C8C99); // Grey text for subtitles/hints

// 3. Soft Pastel Accent Colors for diversity
const Color softLavender = Color(0xFFE9E5FF); // Accent for backgrounds/selections
const Color softCyan = Color(0xFFE8F8FF); // Accent for card/mode backgrounds
const Color softPeach = Color(0xFFFFEEEA); // A complimentary third pastel (if needed)

// 4. Structural Colors & Metrics
const Color primaryBackground = Color(0xFFFFFFFF); // Pure white background
const Color cardBackground = Color(0xFFFFFFFF); // Pure white for card surfaces
const double cardBorderRadius = 24.0; // Highly rounded corners

// 5. Subtle Shadow (Purple-tinted for floating effect)
List<BoxShadow> get subtleShadow => [
  BoxShadow(
    color: const Color.fromARGB(255, 155, 141, 255).withOpacity(0.4),
    blurRadius: 20,
    offset: const Offset(0, 10),
  ),
];

// 6. Theme Utility Helper
double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScaleFactor = MediaQuery.of(context).textScaleFactor;
  const mitigationFactor = 0.8;
  return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
}

// -----------------------------------------------------------------------------

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  // Helper widget to build the themed header area (FLEXIBLE)
  Widget _buildHeader(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      // FLEXIBLE PADDING
      padding: EdgeInsets.only(bottom: screenHeight * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Align icon and title side-by-side
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Icon
              Icon(
                Icons.sports_esports_rounded,
                // FLEXIBLE SIZE
                size: adaptiveFontSize(context, 0.08),
                color: primaryThemePurple,
              ),
              // FLEXIBLE SPACING
              SizedBox(width: screenWidth * 0.03),
              // Main Title
              Text(
                'Games',
                style: TextStyle(
                  // FLEXIBLE FONT SIZE
                  fontSize: adaptiveFontSize(context, 0.065),
                  fontWeight: FontWeight.bold,
                  color: hpDeepBlue,
                ),
              ),
            ],
          ),
          // FLEXIBLE SPACING
          SizedBox(height: screenHeight * 0.01),
          // Subtitle
          Text(
            'Mini games to train attention',
            style: TextStyle(
              // FLEXIBLE FONT SIZE
              fontSize: adaptiveFontSize(context, 0.035),
              color: secondaryTextGrey,
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build a themed game card (FLEXIBLE)
  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final iconBgColor = accentColor.withOpacity(0.1); 

    return Container(
      // FLEXIBLE MARGIN
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))], // Subtle card-level shadow
      ),
      child: Material( 
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Placeholder for navigation logic
          },
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: Padding(
            // FLEXIBLE PADDING
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.025,
              horizontal: screenWidth * 0.05,
            ),
            child: Row(
              children: [
                // 1. Large Circular Icon Container (Leading)
                Container(
                  // FLEXIBLE SIZE
                  width: screenWidth * 0.12,
                  height: screenWidth * 0.12,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                  ),
                  child: Icon(
                    icon,
                    // FLEXIBLE SIZE
                    size: screenWidth * 0.06,
                    color: accentColor,
                  ),
                ),
                // FLEXIBLE SPACING
                SizedBox(width: screenWidth * 0.04),

                // 2. Text Content (Expanded to fill space)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          // FLEXIBLE FONT SIZE
                          fontSize: adaptiveFontSize(context, 0.045),
                          fontWeight: FontWeight.bold,
                          color: primaryTextDark,
                        ),
                      ),
                      
                      // FLEXIBLE SPACING
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        subtitle,
                        style: TextStyle(
                          // FLEXIBLE FONT SIZE
                          fontSize: adaptiveFontSize(context, 0.035),
                          color: secondaryTextGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 3. Trailing Arrow
                Icon(Icons.arrow_forward_ios_rounded, size: screenWidth * 0.04, color: secondaryTextGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for the "Why Warm-Up?" insight block (FLEXIBLE)
  Widget _buildInsightCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final iconSize = screenWidth * 0.055;

    return Container(
      // FLEXIBLE MARGIN
      margin: EdgeInsets.only(top: screenHeight * 0.03),
      // FLEXIBLE PADDING
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: softLavender, 
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow, // Apply main theme shadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.psychology_alt, color: primaryThemePurple, size: adaptiveFontSize(context, 0.06)),
              // FLEXIBLE SPACING
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Why Warm-Up?',
                style: TextStyle(
                  // FLEXIBLE FONT SIZE
                  fontSize: adaptiveFontSize(context, 0.045),
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          // FLEXIBLE SPACING
          SizedBox(height: screenHeight * 0.02),

          // Insights list
          _buildInsightPoint(
            context,
            Icons.speed_rounded, 
            'Mental Activation', 
            'prepares your brain for focused work',
            iconSize
          ),
          _buildInsightPoint(
            context,
            Icons.compare_arrows_rounded, 
            'Quick Transition', 
            'Smooth shifts into deep focus modes',
            iconSize
          ),
          _buildInsightPoint(
            context,
            Icons.star_half_rounded, 
            'Optional enhancement', 
            'Use when you need extra mental clarity',
            iconSize
          ),
        ],
      ),
    );
  }

  // Helper for individual bullet points in the insight block (FLEXIBLE)
  Widget _buildInsightPoint(
    BuildContext context, 
    IconData icon, 
    String boldText, 
    String lightText,
    double iconSize,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      // FLEXIBLE PADDING
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: hpDeepBlue, size: iconSize),
            // FLEXIBLE SPACING
            SizedBox(width: screenWidth * 0.03),
            Expanded( // Ensures the text content takes available space and wraps
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    // FLEXIBLE FONT SIZE
                    fontSize: adaptiveFontSize(context, 0.035),
                    color: primaryTextDark,
                    height: 1.4,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: '$boldText: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: lightText,
                      style: TextStyle(fontWeight: FontWeight.normal, color: secondaryTextGrey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // Use proportional horizontal padding, consistent with HomePage
    final proportionalHorizontalPadding = screenWidth * 0.1; 

    return Scaffold(
      backgroundColor: primaryBackground,
      body: Container(
        decoration: BoxDecoration(
          // Subtle purple glow on the white background
          gradient: LinearGradient(
            colors: [
              primaryBackground,
              softAccentHighlight.withOpacity(0.3),
              primaryBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: proportionalHorizontalPadding,
              right: proportionalHorizontalPadding,
              // Match the top padding of the body content from HomePage/ProgressScreen
              top: screenHeight * 0.1, 
              bottom: screenHeight * 0.025,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with icon and title side-by-side
                _buildHeader(context),
                
                // FLEXIBLE SPACING
                SizedBox(height: screenHeight * 0.015), 

                // 2. Game Cards
                _buildGameCard(
                  context: context,
                  title: 'Riddles & Logic',
                  subtitle: 'Test your quick thinking and logic skills',
                  icon: Icons.lightbulb_outline,
                  accentColor: primaryThemePurple,
                ),
                
                _buildGameCard(
                  context: context,
                  title: 'Math Challenges',
                  subtitle: 'Quickly solve problems to boost focus',
                  icon: Icons.calculate_outlined,
                  accentColor: hpDeepBlue, 
                ),
                
                // 3. Insight Section (Why Warm-Up?)
                _buildInsightCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}