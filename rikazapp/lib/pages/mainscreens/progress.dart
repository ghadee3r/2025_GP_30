import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

final supabase = sb.Supabase.instance.client;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final List<String> tabs = const ['Daily', 'Weekly', 'Monthly'];

  // Locked streak value
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

  // Build custom tab toggle
  Widget _buildCustomTabToggle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenHeight * 0.005),
      decoration: BoxDecoration(
        color: secondaryTextGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final String text = tabs[index];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                decoration: BoxDecoration(
                  color: isSelected ? primaryThemeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryThemeColor.withOpacity(0.3),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: adaptiveFontSize(context, 0.038),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : secondaryTextGrey,
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

  // Build mock chart card
  Widget _buildMockChartCard({
    required BuildContext context,
    required String period,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight * 0.3,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: accentThemeColor,
                size: adaptiveFontSize(context, 0.05),
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                '$period Focus Time',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.04),
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentThemeColor.withOpacity(0.15),
                    lightestAccentColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentThemeColor.withOpacity(0.2),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    color: accentThemeColor,
                    size: screenWidth * 0.12,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Chart Coming Soon',
                    style: TextStyle(
                      fontSize: adaptiveFontSize(context, 0.035),
                      color: secondaryTextGrey,
                      fontStyle: FontStyle.italic,
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

  // Build data summary card
  Widget _buildDataSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.012),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              color: accentThemeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: accentThemeColor,
              size: adaptiveFontSize(context, 0.05),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: adaptiveFontSize(context, 0.04),
                color: primaryTextDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: adaptiveFontSize(context, 0.04),
              fontWeight: FontWeight.bold,
              color: primaryThemeColor,
            ),
          ),
        ],
      ),
    );
  }

  // Build tab content
  Widget _buildTabContent(BuildContext context, String period) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine productive time based on period
    String productiveTime;
    if (period == 'Daily') {
      productiveTime = '1h 30m';
    } else if (period == 'Weekly') {
      productiveTime = '12h 40m';
    } else {
      productiveTime = '50h 15m';
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: screenHeight * 0.02,
        bottom: screenHeight * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart card
          _buildMockChartCard(context: context, period: period),

          // Summary section title
          Text(
            'Summary',
            style: TextStyle(
              fontSize: adaptiveFontSize(context, 0.045),
              fontWeight: FontWeight.bold,
              color: primaryTextDark,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),

          // Data summary cards
          _buildDataSummaryCard(
            context: context,
            title: 'Total Focus Time',
            value: productiveTime,
            icon: Icons.timer_outlined,
          ),

          _buildDataSummaryCard(
            context: context,
            title: 'Current Streak',
            value: currentStreakValue,
            icon: Icons.local_fire_department_rounded,
          ),

          _buildDataSummaryCard(
            context: context,
            title: 'Sessions Completed',
            value: period == 'Daily'
                ? '3'
                : period == 'Weekly'
                ? '18'
                : '76',
            icon: Icons.check_circle_outline_rounded,
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
      resizeToAvoidBottomInset: false,
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,

        title: Text(
          'Progress',
          style: TextStyle(
            fontSize: adaptiveFontSize(context, 0.045),
            fontWeight: FontWeight.bold,
            color: primaryTextDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: proportionalHorizontalPadding,
            right: proportionalHorizontalPadding,
            top: screenHeight * 0.02,
            bottom: screenHeight * 0.025,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title and subtitle
              Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.055),
                  fontWeight: FontWeight.w800,
                  color: primaryTextDark,
                ),
              ),
              Text(
                'Track your productivity and streaks',
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.035),
                  color: secondaryTextGrey,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Custom tab toggle
              _buildCustomTabToggle(context),
              SizedBox(height: screenHeight * 0.02),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: tabs
                      .map((period) => _buildTabContent(context, period))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}