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

// =============================================================================

// Get the Supabase client instance
final supabase = sb.Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State (Functionality Untouched)
  bool isDarkMode = false; // State to control theme colors
  String userName = 'Loading...';
  String userEmail = '';

  List<Map<String, dynamic>> presets = [
    {'id': '1', 'name': 'Deep Work', 'sensitivity': 'High', 'triggers': 3},
    {'id': '2', 'name': 'Morning Focus', 'sensitivity': 'Low', 'triggers': 1},
    {'id': '3', 'name': 'Study Session', 'sensitivity': 'Mid', 'triggers': 4},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- Profile Data Fetching (Logic Untouched) ---
  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;

      String fetchedName = 'User';
      final metadataName = metadata?['full_name'] as String?;
      if (metadataName != null && metadataName.isNotEmpty) {
        fetchedName = metadataName;
      } else {
        fetchedName = user.email?.split('@')[0] ?? 'User';
      }

      final formattedName = fetchedName.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');

      if (mounted) {
        setState(() {
          userEmail = user.email ?? 'No Email';
          userName = formattedName;
        });
      }
    }
  }

  void handleDeletePreset(String id) {
    // Logic for deleting preset is untouched
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Preset', style: TextStyle(color: primaryTextDark)),
        content: Text('Are you sure you want to delete this preset?', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: secondaryTextGrey)),
          ),
          TextButton(
            onPressed: () {
              setState(() => presets.removeWhere((p) => p['id'] == id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Secure Logout Logic (Logic Untouched) ---
  void handleSignOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  void addPreset() {
    // Placeholder for navigation to add preset screen
    // Navigator.pushNamed(context, '/add-preset');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add Preset function triggered!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Theme Variables (Adapted for Dark Mode toggle)
    final bgColor = isDarkMode ? hpThinBlack : primaryBackground;
    final cardColor = isDarkMode ? const Color(0xFF1F1F1F) : cardBackground;
    final primaryTextColor = isDarkMode ? Colors.white : primaryTextDark;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : secondaryTextGrey;
    final highlightColor = primaryThemePurple;
    final tagBackgroundColor = isDarkMode ? const Color(0xFF333333) : softAccentHighlight;
    final tagTextColor = isDarkMode ? Colors.white : hpThinBlack;
    
    // Proportional Padding/Size Constants (using theme's pattern)
    // Used 10% horizontal padding from HomePage for consistent feel
    final proportionalHorizontalPadding = screenWidth * 0.1; 
    final profileAvatarRadius = screenWidth * 0.12; 
    final editIconSize = screenWidth * 0.045;
    final itemVerticalPadding = screenHeight * 0.02;

    return Scaffold(
      // FIX: Apply resizeToAvoidBottomInset: false
      resizeToAvoidBottomInset: false, 
      backgroundColor: bgColor,
      body: Container(
        // Apply the subtle purple gradient glow from the home page
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              bgColor,
              softAccentHighlight.withOpacity(isDarkMode ? 0.1 : 0.3),
              bgColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // FLEXIBLE PADDING
            padding: EdgeInsets.only(bottom: screenHeight * 0.03),
            child: Column(
              children: [
                // 1. Profile Header
                Container(
                  // FLEXIBLE PADDING
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.04),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: secondaryTextGrey.withOpacity(0.3), width: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            // FLEXIBLE RADIUS
                            radius: profileAvatarRadius,
                            // Use a purple background placeholder
                            backgroundColor: softLavender, 
                            child: Text(
                              userName.isNotEmpty ? userName[0] : 'U',
                              style: TextStyle(
                                fontSize: adaptiveFontSize(context, 0.07),
                                fontWeight: FontWeight.bold,
                                color: highlightColor,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardBackground, // White edit background
                                shape: BoxShape.circle,
                                // Use subtle shadow
                                boxShadow: subtleShadow.map((s) => s.copyWith(blurRadius: 10, offset: const Offset(0, 5))).toList(),
                              ),
                              // FLEXIBLE PADDING
                              padding: EdgeInsets.all(screenWidth * 0.012),
                              child: Icon(
                                Icons.edit,
                                // FLEXIBLE SIZE
                                size: editIconSize,
                                color: hpDeepBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // FLEXIBLE SPACING
                      SizedBox(height: screenHeight * 0.012),
                      Text(
                        userName, // Dynamically fetched name
                        style: TextStyle(
                          // FLEXIBLE FONT SIZE
                          fontSize: adaptiveFontSize(context, 0.06),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        userEmail, // Dynamically fetched email
                        style: TextStyle(
                          // FLEXIBLE FONT SIZE
                          fontSize: adaptiveFontSize(context, 0.035),
                          color: secondaryTextColor,
                        ),
                      ),
                      // FLEXIBLE SPACING
                      SizedBox(height: screenHeight * 0.025),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: highlightColor,
                          shape: RoundedRectangleBorder(
                            // Enforce theme's half border radius
                            borderRadius: BorderRadius.circular(cardBorderRadius / 2), 
                          ),
                          // FLEXIBLE PADDING
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05,
                            vertical: screenHeight * 0.012,
                          ),
                          elevation: 4,
                          shadowColor: highlightColor.withOpacity(0.5),
                        ),
                        onPressed: () {},
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            // FLEXIBLE FONT SIZE
                            fontSize: adaptiveFontSize(context, 0.04),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Rikaz Tools Presets Section
                _Section(
                  title: 'Rikaz Tools Presets',
                  count: '${presets.length}/5',
                  textColor: primaryTextColor,
                  horizontalMargin: proportionalHorizontalPadding, // Pass proportional margin
                  // FIX: Removed the large "Add New Preset" card/button from the column, 
                  // it will be replaced by the IconButton in the _Section header.
                  child: Column(
                    children: [
                      // List of Presets
                      ...presets.map(
                        (preset) => Container(
                          // FLEXIBLE MARGIN
                          margin: EdgeInsets.only(bottom: screenHeight * 0.012),
                          // FLEXIBLE PADDING
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: cardColor,
                            // Use theme's half border radius for consistency
                            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                            // Use subtle shadow for floating effect
                            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preset['name'],
                                      style: TextStyle(
                                        // FLEXIBLE FONT SIZE
                                        fontSize: adaptiveFontSize(context, 0.045),
                                        fontWeight: FontWeight.bold,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    // FLEXIBLE SPACING
                                    SizedBox(height: screenHeight * 0.006),
                                    Row(
                                      // Ensure tags wrap if necessary, but keep them compact
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _Tag(
                                          text: '${preset['sensitivity']} Sensitivity',
                                          fontSize: adaptiveFontSize(context, 0.03),
                                          backgroundColor: tagBackgroundColor,
                                          textColor: tagTextColor,
                                        ),
                                        _Tag(
                                          text: '${preset['triggers']} Triggers',
                                          fontSize: adaptiveFontSize(context, 0.03),
                                          backgroundColor: tagBackgroundColor,
                                          textColor: tagTextColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_note,
                                        // FLEXIBLE SIZE
                                        size: screenWidth * 0.06, color: highlightColor),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_forever,
                                        // FLEXIBLE SIZE
                                        size: screenWidth * 0.06, color: Colors.red.shade400),
                                    onPressed: () =>
                                        handleDeletePreset(preset['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Settings Section
                _Section(
                  title: 'Settings',
                  textColor: primaryTextColor,
                  horizontalMargin: proportionalHorizontalPadding, // Pass proportional margin
                  child: Column(
                    children: [
                      _SettingsItem(
                        icon: Icons.security,
                        label: 'Privacy',
                        textColor: primaryTextColor,
                        cardColor: cardColor,
                        itemVerticalPadding: itemVerticalPadding, // Pass proportional padding
                        fontSize: adaptiveFontSize(context, 0.04),
                        iconColor: highlightColor,
                        onTap: () {},
                      ),
                      _SettingsItem(
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        textColor: primaryTextColor,
                        cardColor: cardColor,
                        itemVerticalPadding: itemVerticalPadding,
                        fontSize: adaptiveFontSize(context, 0.04),
                        iconColor: highlightColor,
                        onTap: () {},
                      ),
                      // Dark Mode Toggle (Themed)
                      Container(
                        // FLEXIBLE MARGIN
                        margin: EdgeInsets.only(bottom: screenHeight * 0.012),
                        // FLEXIBLE PADDING
                        padding: EdgeInsets.symmetric(vertical: itemVerticalPadding, horizontal: screenWidth * 0.05),
                        decoration: BoxDecoration(
                          color: cardColor,
                          // Enforce theme's half border radius
                          borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                          boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.dark_mode, color: highlightColor, size: screenWidth * 0.05),
                                SizedBox(width: screenWidth * 0.025),
                                Text('Dark Mode',
                                    style: TextStyle(
                                        color: primaryTextColor, 
                                        fontSize: adaptiveFontSize(context, 0.04))),
                              ],
                            ),
                            Switch(
                              value: isDarkMode,
                              onChanged: (val) => setState(() => isDarkMode = val),
                              activeColor: highlightColor, // Use the theme's purple
                              inactiveThumbColor: secondaryTextGrey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Sign Out Section
                _Section(
                  textColor: primaryTextColor,
                  horizontalMargin: proportionalHorizontalPadding, // Pass proportional margin
                  child: _SettingsItem(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    textColor: Colors.red.shade400, // Use a contrasting color for logout
                    cardColor: cardColor,
                    trailing: Icons.chevron_right,
                    itemVerticalPadding: itemVerticalPadding,
                    fontSize: adaptiveFontSize(context, 0.04),
                    iconColor: Colors.red.shade400,
                    onTap: handleSignOut,
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

/* ---------- Helper Components (Themed and Flexible) ---------- */

class _Section extends StatelessWidget {
  final String? title;
  final String? count;
  final Color textColor;
  final Widget child;
  final double horizontalMargin; // Added for flexible margins

  const _Section({
    this.title,
    this.count,
    required this.textColor,
    required this.child,
    required this.horizontalMargin,
  });

  // FIX: Overridden build method to integrate the Add Preset button 
  // directly into the title row for the "Rikaz Tools Presets" section.
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      // Use proportional margin passed from parent
      margin: EdgeInsets.only(top: screenWidth * 0.05, bottom: screenWidth * 0.03, left: horizontalMargin, right: horizontalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              // Add a small bottom padding to separate title from content
              padding: EdgeInsets.only(bottom: screenWidth * 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title and Count
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(title!,
                          style: TextStyle(
                              // FLEXIBLE FONT SIZE using helper
                              fontSize: adaptiveFontSize(context, 0.045),
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      if (count != null)
                        Padding(
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Text(count!,
                              style: TextStyle(
                                  // FLEXIBLE FONT SIZE using helper
                                  fontSize: adaptiveFontSize(context, 0.035),
                                  color: secondaryTextGrey)),
                        ),
                    ],
                  ),
                  
                  // FIX: Small elegant Add Preset Button (Only for the Preset section)
                  if (title == 'Rikaz Tools Presets')
                    Builder(
                      builder: (context) {
                        final _ProfileScreenState state = context.findAncestorStateOfType<_ProfileScreenState>()!;
                        return IconButton(
                          icon: Icon(Icons.add_circle, color: primaryThemePurple, size: screenWidth * 0.06),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: state.addPreset,
                          tooltip: 'Add New Preset',
                        );
                      }
                    ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final Color textColor;
  final Color cardColor;
  final Color iconColor;
  final VoidCallback onTap;
  final double itemVerticalPadding; // Added for flexible padding
  final double fontSize; // Added for flexible font size

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.cardColor,
    required this.onTap,
    required this.itemVerticalPadding,
    required this.fontSize,
    required this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // FLEXIBLE MARGIN
        margin: EdgeInsets.only(bottom: screenWidth * 0.03),
        // FLEXIBLE PADDING
        padding: EdgeInsets.symmetric(vertical: itemVerticalPadding, horizontal: screenWidth * 0.05),
        decoration: BoxDecoration(
          color: cardColor,
          // Enforce theme's half border radius
          borderRadius: BorderRadius.circular(cardBorderRadius / 2),
          // Add subtle shadow for consistency
          boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // FLEXIBLE ICON SIZE
                Icon(icon, color: iconColor, size: screenWidth * 0.05),
                // FLEXIBLE SPACING
                SizedBox(width: screenWidth * 0.025),
                Text(label,
                    style: TextStyle(fontSize: fontSize, color: textColor)),
              ],
            ),
            if (trailing != null)
              // FLEXIBLE ICON SIZE
              Icon(trailing, color: secondaryTextGrey, size: screenWidth * 0.05),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final double fontSize; // Added for flexible font size
  final Color backgroundColor;
  final Color textColor;

  const _Tag({
    required this.text, 
    required this.fontSize, 
    required this.backgroundColor, 
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Flexible( // Make the tag flexible so it can shrink
      child: Container(
        // FLEXIBLE MARGIN
        margin: EdgeInsets.only(right: screenWidth * 0.012),
        // FLEXIBLE PADDING
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenWidth * 0.01),
        decoration: BoxDecoration(
          color: backgroundColor, // Themed background
          // Slightly smaller radius for tags
          borderRadius: BorderRadius.circular(screenWidth * 0.012),
        ),
        child: Text(
          text,
          // ENSURE TEXT DOES NOT OVERFLOW
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          // FLEXIBLE FONT SIZE
          style: TextStyle(fontSize: fontSize, color: textColor.withOpacity(0.8)), // Themed text color
        ),
      ),
    );
  }
}