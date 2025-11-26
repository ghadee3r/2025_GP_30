import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

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

// Error/alert color
const Color errorIndicatorRed = Color(0xFFE57373);

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

const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/calendar',
  'email',
];

class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  calendar.CalendarApi? calendarApi;

  bool get isConnected => calendarApi != null;

  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final authenticatedClient = await _googleSignIn.authenticatedClient();

      if (authenticatedClient != null) {
        calendarApi = calendar.CalendarApi(authenticatedClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    calendarApi = null;
  }
}

final supabase = sb.Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = 'Loading...';
  String userEmail = '';
  bool isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  
  // Google Calendar state
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeGoogleCalendar();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  // Initialize Google Calendar connection
  void _initializeGoogleCalendar() {
    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _client.signIn().then((success) {
          if (mounted) {
            setState(() {
              _isCalendarConnected = success;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isCalendarConnected = false;
          });
        }
      }
    });
    
    _client._googleSignIn.signInSilently();
  }

  // Load user profile data
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
          _nameController.text = formattedName;
        });
      }
    }
  }

  // Save updated name
  Future<void> _saveUserName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showErrorSnackBar('Name cannot be empty');
      return;
    }

    try {
      await supabase.auth.updateUser(
        sb.UserAttributes(
          data: {'full_name': newName},
        ),
      );

      if (mounted) {
        setState(() {
          userName = newName;
          isEditingName = false;
        });
        _showSuccessSnackBar('Name updated successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update name: $e');
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorIndicatorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Handle sign out - With confirmation dialog
  Future<void> handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out', style: TextStyle(color: primaryTextDark)),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: secondaryTextGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorIndicatorRed),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }
  
  // Handle Google Calendar sign in
  Future<void> _handleCalendarSignIn() async {
    if (_isCalendarConnected) return;
    setState(() { _isSigningIn = true; });
    
    final success = await _client.signIn();
    
    if (!mounted) return;

    setState(() {
      _isCalendarConnected = success;
      _isSigningIn = false;
    });

    if (success) {
      _showSuccessSnackBar('Google Calendar connected successfully!');
    } else {
      _showErrorSnackBar('Failed to connect Google Calendar');
    }
  }

  // Handle Google Calendar sign out
  Future<void> _handleCalendarSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Disconnect Google Calendar?',
        content: 'Your calendar events will no longer sync with the app.',
        icon: Icons.cloud_off_rounded,
        iconColor: errorIndicatorRed,
        cancelText: 'Cancel',
        confirmText: 'Disconnect',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true) {
      await _client.signOut();
      setState(() {
        _isCalendarConnected = false;
      });
      _showSuccessSnackBar('Google Calendar disconnected');
    }
  }

  // Build themed dialog
  Widget _buildThemedDialog({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required String cancelText,
    required String confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: MediaQuery.of(context).size.width * 0.12,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: adaptiveFontSize(context, 0.045),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.015),
            
            // Content
            Text(
              content,
              style: TextStyle(
                fontSize: adaptiveFontSize(context, 0.035),
                color: secondaryTextGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.025),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel ?? () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: secondaryTextGrey.withOpacity(0.3)),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        color: secondaryTextGrey,
                        fontSize: adaptiveFontSize(context, 0.035),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onConfirm != null) onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryThemeColor,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: adaptiveFontSize(context, 0.035),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build settings item
  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                color: (textColor ?? accentThemeColor).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: textColor ?? accentThemeColor,
                size: adaptiveFontSize(context, 0.05),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: adaptiveFontSize(context, 0.04),
                  fontWeight: FontWeight.w600,
                  color: textColor ?? primaryTextDark,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: secondaryTextGrey,
              size: adaptiveFontSize(context, 0.05),
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
    final proportionalHorizontalPadding = screenWidth * 0.05;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,

        title: Text(
          'Profile',
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
            children: [
              // Profile Header - No Card Wrapper
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: proportionalHorizontalPadding,
                  vertical: screenHeight * 0.03,
                ),
                child: Column(
                  children: [
                    // Avatar (no icon beside it)
                    CircleAvatar(
                      radius: screenWidth * 0.12,
                      backgroundColor: accentThemeColor.withOpacity(0.2),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: adaptiveFontSize(context, 0.08),
                          fontWeight: FontWeight.bold,
                          color: accentThemeColor,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    // Name (Editable)
                    if (isEditingName)
                      Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            style: TextStyle(
                              fontSize: adaptiveFontSize(context, 0.045),
                              fontWeight: FontWeight.bold,
                              color: primaryTextDark,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: TextStyle(color: secondaryTextGrey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: accentThemeColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: accentThemeColor, width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04,
                                vertical: screenHeight * 0.015,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    isEditingName = false;
                                    _nameController.text = userName;
                                  });
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: secondaryTextGrey,
                                    fontSize: adaptiveFontSize(context, 0.035),
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              ElevatedButton(
                                onPressed: _saveUserName,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryThemeColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.05,
                                    vertical: screenHeight * 0.012,
                                  ),
                                ),
                                child: Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: adaptiveFontSize(context, 0.035),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: adaptiveFontSize(context, 0.05),
                              fontWeight: FontWeight.bold,
                              color: primaryTextDark,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: adaptiveFontSize(context, 0.035),
                              color: secondaryTextGrey,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                isEditingName = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentThemeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.05,
                                vertical: screenHeight * 0.012,
                              ),
                              elevation: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: adaptiveFontSize(context, 0.04)),
                                SizedBox(width: screenWidth * 0.02),
                                Text(
                                  'Edit Name',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: adaptiveFontSize(context, 0.035),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Settings Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: proportionalHorizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: adaptiveFontSize(context, 0.045),
                        fontWeight: FontWeight.bold,
                        color: primaryTextDark,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),

                    // Google Calendar Connection (matching settings items)
                    GestureDetector(
                      onTap: _isSigningIn 
                        ? null 
                        : (_isCalendarConnected ? _handleCalendarSignOut : _handleCalendarSignIn),
                      child: Container(
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
                                color: (_isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _isSigningIn
                                ? SizedBox(
                                    width: adaptiveFontSize(context, 0.05),
                                    height: adaptiveFontSize(context, 0.05),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(accentThemeColor),
                                    ),
                                  )
                                : Icon(
                                    _isCalendarConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                    color: _isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey,
                                    size: adaptiveFontSize(context, 0.05),
                                  ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Calendar',
                                    style: TextStyle(
                                      fontSize: adaptiveFontSize(context, 0.04),
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextDark,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.003),
                                  Text(
                                    _isCalendarConnected ? 'Connected' : 'Not connected',
                                    style: TextStyle(
                                      fontSize: adaptiveFontSize(context, 0.03),
                                      color: secondaryTextGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: secondaryTextGrey,
                              size: adaptiveFontSize(context, 0.05),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildSettingsItem(
                      icon: Icons.security_rounded,
                      label: 'Privacy',
                      onTap: () {
                        // Navigate to privacy settings
                      },
                    ),

                    _buildSettingsItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () {
                        // Navigate to help & support
                      },
                    ),

                    _buildSettingsItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      textColor: errorIndicatorRed,
                      onTap: handleSignOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}