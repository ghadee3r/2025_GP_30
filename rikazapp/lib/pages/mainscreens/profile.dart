import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../subscreens/create_preset.dart'; // Make sure this is imported!

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
const Color errorIndicatorRed = Color(0xFFE57373);

const double cardBorderRadius = 16.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(color: dfNavyIndigo.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5)),
    ];

double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScaleFactor = MediaQuery.of(context).textScaleFactor;
  return baseSize / (1.0 + (textScaleFactor - 1.0) * 0.9);
}

// =============================================================================

const List<String> _scopes = <String>['https://www.googleapis.com/auth/calendar', 'email'];

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
  
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;

  // --- PRESETS STATE ---
  List<Map<String, dynamic>> _userPresets = [];
  bool _isLoadingPresets = true;
  final int _maxPresetsLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeGoogleCalendar();
    _loadPresets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA FETCHING & LOGIC
  // ===========================================================================
  
  void _initializeGoogleCalendar() {
    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _client.signIn().then((success) {
          if (mounted) setState(() => _isCalendarConnected = success);
        });
      } else {
        if (mounted) setState(() => _isCalendarConnected = false);
      }
    });
    _client._googleSignIn.signInSilently();
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      String fetchedName = metadata?['full_name'] as String? ?? user.email?.split('@')[0] ?? 'User';
      
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

  Future<void> _loadPresets() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase.from('Preset').select().eq('user_id', userId);

      if (mounted) {
        setState(() {
          _userPresets = List<Map<String, dynamic>>.from(response);
          _isLoadingPresets = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading presets: $e');
      if (mounted) setState(() => _isLoadingPresets = false);
    }
  }

  Future<void> _deletePreset(String presetId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: const Text('Are you sure you want to delete this preset?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: errorIndicatorRed),
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('Preset').delete().eq('Preset_id', presetId);
        _showSuccessSnackBar('Preset deleted');
        _loadPresets(); // Refresh the list
      } catch (e) {
        _showErrorSnackBar('Failed to delete preset: $e');
      }
    }
  }

  Future<void> _saveUserName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showErrorSnackBar('Name cannot be empty');
      return;
    }
    try {
      await supabase.auth.updateUser(sb.UserAttributes(data: {'full_name': newName}));
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

  // ... (Keep _showErrorSnackBar, _showSuccessSnackBar, handleSignOut, _handleCalendarSignIn, _handleCalendarSignOut, _buildThemedDialog, _buildSettingsItem from your previous code)
  
  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]), backgroundColor: errorIndicatorRed, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating));
  }

  Future<void> handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out', style: TextStyle(color: primaryTextDark)),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: secondaryTextGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: errorIndicatorRed), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
  
  Future<void> _handleCalendarSignIn() async {
    if (_isCalendarConnected) return;
    setState(() { _isSigningIn = true; });
    final success = await _client.signIn();
    if (!mounted) return;
    setState(() {
      _isCalendarConnected = success;
      _isSigningIn = false;
    });
    if (success) _showSuccessSnackBar('Google Calendar connected successfully!');
    else _showErrorSnackBar('Failed to connect Google Calendar');
  }

  Future<void> _handleCalendarSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text('Your calendar events will no longer sync with the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: errorIndicatorRed), child: const Text('Disconnect')),
        ],
      )
    );

    if (confirmed == true) {
      await _client.signOut();
      setState(() => _isCalendarConnected = false);
      _showSuccessSnackBar('Google Calendar disconnected');
    }
  }

  Widget _buildSettingsItem({required IconData icon, required String label, required VoidCallback onTap, Color? textColor}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.025),
              decoration: BoxDecoration(color: (textColor ?? accentThemeColor).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: textColor ?? accentThemeColor, size: adaptiveFontSize(context, 0.05)),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(child: Text(label, style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), fontWeight: FontWeight.w600, color: textColor ?? primaryTextDark))),
            Icon(Icons.chevron_right, color: secondaryTextGrey, size: adaptiveFontSize(context, 0.05)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

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
        title: Text('Profile', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: proportionalHorizontalPadding, right: proportionalHorizontalPadding, top: screenHeight * 0.02, bottom: screenHeight * 0.03),
          child: Column(
            children: [
              // ---------------------------------------------------------------
              // Profile Header 
              // ---------------------------------------------------------------
              Padding(
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: screenWidth * 0.12,
                      backgroundColor: accentThemeColor.withOpacity(0.2),
                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: TextStyle(fontSize: adaptiveFontSize(context, 0.08), fontWeight: FontWeight.bold, color: accentThemeColor)),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    if (isEditingName)
                      Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(hintText: 'Enter your name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(onPressed: () => setState(() { isEditingName = false; _nameController.text = userName; }), child: const Text('Cancel')),
                              ElevatedButton(onPressed: _saveUserName, style: ElevatedButton.styleFrom(backgroundColor: primaryThemeColor), child: const Text('Save', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Text(userName, style: TextStyle(fontSize: adaptiveFontSize(context, 0.05), fontWeight: FontWeight.bold, color: primaryTextDark)),
                          SizedBox(height: screenHeight * 0.005),
                          Text(userEmail, style: TextStyle(fontSize: adaptiveFontSize(context, 0.035), color: secondaryTextGrey)),
                          SizedBox(height: screenHeight * 0.02),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => isEditingName = true),
                            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                            label: const Text('Edit Name', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: accentThemeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.01),

              // ---------------------------------------------------------------
              // PRESETS DROP-DOWN (ExpansionTile)
              // ---------------------------------------------------------------
              Container(
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                  boxShadow: subtleShadow,
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true, // Set to false if you want it closed by default
                    title: Text(
                      'My Presets (${_userPresets.length}/$_maxPresetsLimit)',
                      style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark),
                    ),
                    childrenPadding: EdgeInsets.only(left: screenWidth * 0.04, right: screenWidth * 0.04, bottom: screenWidth * 0.04),
                    children: [
                      if (_isLoadingPresets)
                        const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: accentThemeColor))
                      else if (_userPresets.isEmpty)
                        Text('No presets saved yet.', style: TextStyle(color: secondaryTextGrey, fontSize: adaptiveFontSize(context, 0.035)))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _userPresets.length,
                          itemBuilder: (context, index) {
                            final preset = _userPresets[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: primaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: secondaryTextGrey.withOpacity(0.1)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.tune_rounded, color: accentThemeColor),
                                ),
                                title: Text(preset['preset_name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: secondaryTextGrey),
                                      onPressed: () {
                                        // Navigate to edit page and wait for result
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => CreatePresetPage(presetToEdit: preset)),
                                        ).then((shouldRefresh) {
                                          if (shouldRefresh == true) _loadPresets();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: errorIndicatorRed.withOpacity(0.8)),
                                     onPressed: () => _deletePreset(preset['Preset_id'].toString()),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      
                      // Add New Preset Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _userPresets.length < _maxPresetsLimit
                              ? () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePresetPage())).then((shouldRefresh) {
                                    if (shouldRefresh == true) _loadPresets();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add New Preset', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: accentThemeColor,
                            disabledForegroundColor: secondaryTextGrey.withOpacity(0.5),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // ---------------------------------------------------------------
              // Settings Section
              // ---------------------------------------------------------------
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
                  SizedBox(height: screenHeight * 0.015),
                  
                  // Google Calendar
                  GestureDetector(
                    onTap: _isSigningIn ? null : (_isCalendarConnected ? _handleCalendarSignOut : _handleCalendarSignIn),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.025),
                            decoration: BoxDecoration(color: (_isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: _isSigningIn
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(accentThemeColor)))
                              : Icon(_isCalendarConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: _isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Google Calendar', style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), fontWeight: FontWeight.w600, color: primaryTextDark)),
                                SizedBox(height: screenHeight * 0.003),
                                Text(_isCalendarConnected ? 'Connected' : 'Not connected', style: TextStyle(fontSize: adaptiveFontSize(context, 0.03), color: secondaryTextGrey)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: secondaryTextGrey),
                        ],
                      ),
                    ),
                  ),

                  _buildSettingsItem(icon: Icons.security_rounded, label: 'Privacy', onTap: () {}),
                  _buildSettingsItem(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
                  _buildSettingsItem(icon: Icons.logout_rounded, label: 'Sign Out', textColor: errorIndicatorRed, onTap: handleSignOut),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}