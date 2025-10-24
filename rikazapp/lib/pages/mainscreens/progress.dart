import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

// Get the Supabase client instance (mocked/placeholder)
// final supabase = sb.Supabase.instance.client; // Uncomment if full Supabase setup is required

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0; 
  final List<String> tabs = const ['Daily', 'Weekly', 'Monthly'];
  
  // Locked Streak Value
  static const String currentStreakValue = '14 Days'; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Theme Helpers ---

  // FIX: Helper widget to build the themed header area matching Games/Home (FLEXIBLE)
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Icon
              Icon(
                Icons.trending_up_rounded,
                // FLEXIBLE SIZE
                size: adaptiveFontSize(context, 0.08),
                color: primaryThemePurple,
              ),
              // FLEXIBLE SPACING
              SizedBox(width: screenWidth * 0.03),
              // Main Title
              Text(
                'Progress',
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
          // Subtitle below the icon and title row
          Text(
            'Track your productivity and streaks',
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

  // Helper widget for mock chart display (Visual Analysis) (FLEXIBLE)
  Widget _MockChartCard({required BuildContext context, required String period}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      // FLEXIBILITY: Chart height is proportional to screen height
      height: screenHeight * 0.35, 
      width: double.infinity,
      // FLEXIBLE MARGIN
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      // FLEXIBLE PADDING
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
        border: Border.all(color: softLavender, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$period Focus Time',
            style: TextStyle(
              // FLEXIBLE FONT SIZE
              fontSize: adaptiveFontSize(context, 0.04),
              fontWeight: FontWeight.bold,
              color: primaryTextDark,
            ),
          ),
          // FLEXIBLE SPACING
          SizedBox(height: screenHeight * 0.01),
          // Mock Chart Area
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: softCyan,
                  borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mock ${period} Chart (Visual Data)',
                  style: TextStyle(
                    // FLEXIBLE FONT SIZE
                    fontSize: adaptiveFontSize(context, 0.035),
                    color: hpDeepBlue,
                    fontStyle: FontStyle.italic
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for numerical summaries (FLEXIBLE)
  Widget _DataSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      // FLEXIBLE MARGIN
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      // FLEXIBLE PADDING
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius / 2), // Smaller radius for list items
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title (Fixed width for predictability or simply left-aligned)
          Row(
            children: [
              // FLEXIBLE ICON SIZE
              Icon(icon, color: primaryThemePurple, size: screenWidth * 0.05),
              // FLEXIBLE SPACING
              SizedBox(width: screenWidth * 0.03),
              Text(
                title,
                style: TextStyle(
                  // FLEXIBLE FONT SIZE
                  fontSize: adaptiveFontSize(context, 0.04),
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          // Trailing value uses Expanded to prevent overflow, with ellipsis fallback
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // FLEXIBLE FONT SIZE
                fontSize: adaptiveFontSize(context, 0.04),
                fontWeight: FontWeight.bold,
                color: hpDeepBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Content for each tab (FLEXIBLE)
  Widget _buildTabContent(BuildContext context, String period) {
    // Determine mock productive time based on period (Logic untouched)
    String productiveTime;
    if (period == 'Daily') {
      productiveTime = '1h 30m';
    } else if (period == 'Weekly') {
      productiveTime = '12h 40m';
    } else {
      productiveTime = '50h 15m';
    }

    return SingleChildScrollView(
      // Added padding bottom for the Scrollable view
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.02, bottom: MediaQuery.of(context).size.height * 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Analysis (Chart Mockup)
          _MockChartCard(context: context, period: period),

          // Numerical Analysis Summary
          Text(
            'Numerical Summary',
            style: TextStyle(
              // FLEXIBLE FONT SIZE
              fontSize: adaptiveFontSize(context, 0.05),
              fontWeight: FontWeight.bold,
              color: primaryTextDark,
            ),
          ),
          // FLEXIBLE SPACING
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

          _DataSummaryCard(
            context: context,
            title: 'Total Focus Time',
            // Display the mock productive time variable
            value: productiveTime,
            icon: Icons.timer_outlined,
          ),
          // Streak is static
          _DataSummaryCard(
            context: context,
            title: 'Current Streak',
            value: currentStreakValue,
            icon: Icons.local_fire_department_rounded,
          ),

        ],
      ),
    );
  }
  
  // Custom Tab Toggle Button (Mimics the desired style) (FLEXIBLE)
  Widget _buildCustomTabToggle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      // FLEXIBLE PADDING
      padding: EdgeInsets.all(screenHeight * 0.005),
      decoration: BoxDecoration(
        color: softAccentHighlight.withOpacity(0.5), // Pale background for the container
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final String text = tabs[index];
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Update both the custom state and the TabController
                setState(() => _selectedTabIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                // FLEXIBLE PADDING
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                decoration: BoxDecoration(
                  // Selected uses white card background
                  color: isSelected ? cardBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  // Slight shadow for the selected tab only
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
                  // Add a subtle border to separate segments
                  border: isSelected ? Border.all(color: primaryThemePurple.withOpacity(0.1), width: 1) : null,
                ),
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      // FLEXIBLE FONT SIZE
                      fontSize: adaptiveFontSize(context, 0.038),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      // Active color is the primary purple, inactive is dark text
                      color: isSelected ? primaryThemePurple : primaryTextDark.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
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
      // Apply resizeToAvoidBottomInset: false for overflow prevention
      resizeToAvoidBottomInset: false,
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
          child: Padding(
            padding: EdgeInsets.only(
              left: proportionalHorizontalPadding,
              right: proportionalHorizontalPadding,
              // Match the top padding of the body content from HomePage/GamesScreen
              top: screenHeight * 0.1, 
              bottom: screenHeight * 0.025,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header 
                _buildHeader(context),
                
                // FLEXIBLE SPACING
                SizedBox(height: screenHeight * 0.02),

                // 2. Custom Tab Toggle Bar
                _buildCustomTabToggle(context),
                // FLEXIBLE SPACING
                SizedBox(height: screenHeight * 0.02),

                // 3. Tab Content Area (The core of the screen)
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: tabs.map((period) => _buildTabContent(context, period)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}