import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../subscreens/create_preset.dart'; 

// =============================================================================
// THEME DEFINITIONS (Synchronized with Progress Page)
// =============================================================================
const Color dfDeepBlue = Color(0xFF7E84D4);
const Color dfDeepTeal = Color(0xFF1B2536); 
const Color dfTealCyan = Color(0xFF68C29D); 
const Color customModeColor = Color(0xFF7E84D4); 
const Color dfLightSeafoam = Color(0xFFE8F1EC);
const Color dfNavyIndigo = Color(0xFF1B2536); 

const Color primaryThemeColor = dfTealCyan;
const Color accentThemeColor = customModeColor;
const Color lightestAccentColor = dfLightSeafoam;

const Color primaryBackground = Color(0xFFF2F6F9);
const Color cardBackground = Color(0xFFFFFFFF);
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Preset?', style: TextStyle(color: dfNavyIndigo, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this preset?', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: secondaryTextGrey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: errorIndicatorRed),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('Preset').delete().eq('Preset_id', presetId);
        _showSuccessSnackBar('Preset deleted');
        _loadPresets(); 
      } catch (e) {
        _showErrorSnackBar('Failed to delete preset: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]), 
      backgroundColor: errorIndicatorRed, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]), 
      backgroundColor: dfTealCyan, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(color: dfNavyIndigo, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: secondaryTextGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: errorIndicatorRed), child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect Calendar?', style: TextStyle(color: dfNavyIndigo, fontWeight: FontWeight.bold)),
        content: const Text('Your calendar events will no longer sync with the app.', style: TextStyle(color: secondaryTextGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: secondaryTextGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: errorIndicatorRed), child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirmed == true) {
      await _client.signOut();
      setState(() => _isCalendarConnected = false);
      _showSuccessSnackBar('Google Calendar disconnected');
    }
  }

  // ===========================================================================
  // BOTTOM SHEETS
  // ===========================================================================

  void _showPrivacyBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.security_rounded, color: accentThemeColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Privacy Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dfNavyIndigo))),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Camera Monitoring & Your Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
                const SizedBox(height: 12),
                const Text(
                  'Your absolute autonomy and privacy are our highest priorities. The camera monitoring feature in Rikaz is built strictly to detect physical distractions during your focus sessions locally.\n',
                  style: TextStyle(fontSize: 14, color: secondaryTextGrey, height: 1.5),
                ),
                _privacyBullet('Real-Time Processing: ', 'All footage is analyzed instantaneously on your device.'),
                _privacyBullet('Zero Storage: ', 'Video data is never recorded, saved, or stored.'),
                _privacyBullet('Zero Sharing: ', 'Footage is completely inaccessible to our servers or any third parties.'),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: dfNavyIndigo, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyBullet(String boldText, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: customModeColor, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: secondaryTextGrey, height: 1.5, fontFamily: 'Roboto'),
                children: [
                  TextSpan(text: boldText, style: const TextStyle(fontWeight: FontWeight.bold, color: dfNavyIndigo)),
                  TextSpan(text: text),
                ]
              )
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.help_outline_rounded, color: dfTealCyan, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Help & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dfNavyIndigo))),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Need assistance configuring your routines, encountered a bug, or have suggestions for Rikaz?\n\nReach out directly to our support and development team below.',
                  style: TextStyle(fontSize: 14, color: secondaryTextGrey, height: 1.5),
                ),
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Row(
                    children: [
                      const Icon(Icons.email_rounded, color: dfTealCyan),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Email Us At', style: TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text('rikaz.gp@gmail.com', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dfNavyIndigo)),
                        ],
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: dfNavyIndigo, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  Widget _buildSettingsItem({required IconData icon, required String label, required VoidCallback onTap, Color? textColor}) {
    return _InteractivePill(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6), 
          borderRadius: BorderRadius.circular(cardBorderRadius), 
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: subtleShadow
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (textColor ?? accentThemeColor).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: textColor ?? accentThemeColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor ?? primaryTextDark))),
            Icon(Icons.chevron_right_rounded, color: secondaryTextGrey, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          // Glassmorphic Gradient Background matching progress & home page
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, 
                end: Alignment.bottomCenter, 
                colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)]
              )
            )
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Manage your account and settings', style: TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 32),

                  // ---------------------------------------------------------------
                  // Sleek Minimalist Header
                  // ---------------------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6), 
                      borderRadius: BorderRadius.circular(cardBorderRadius), 
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: subtleShadow
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dfNavyIndigo, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text(userEmail, style: const TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ---------------------------------------------------------------
                  // PRESETS DROP-DOWN (Glassmorphic)
                  // ---------------------------------------------------------------
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6), 
                      borderRadius: BorderRadius.circular(cardBorderRadius), 
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: subtleShadow
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        iconColor: dfNavyIndigo,
                        collapsedIconColor: secondaryTextGrey,
                        initiallyExpanded: true,
                        title: Text(
                          'My Presets (${_userPresets.length}/$_maxPresetsLimit)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextDark),
                        ),
                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                        children: [
                          if (_isLoadingPresets)
                            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: accentThemeColor))
                          else if (_userPresets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12.0),
                              child: Text('No presets saved yet.', style: TextStyle(color: secondaryTextGrey, fontSize: 14)),
                            )
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
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.tune_rounded, color: accentThemeColor, size: 20),
                                    ),
                                    title: Text(preset['preset_name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600, color: dfNavyIndigo)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: secondaryTextGrey, size: 20),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => CreatePresetPage(presetToEdit: preset)),
                                            ).then((shouldRefresh) {
                                              if (shouldRefresh == true) _loadPresets();
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: errorIndicatorRed.withOpacity(0.8), size: 20),
                                         onPressed: () => _deletePreset(preset['Preset_id'].toString()),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          const SizedBox(height: 8),
                          
                          // Add New Preset Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _userPresets.length < _maxPresetsLimit
                                  ? () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePresetPage())).then((shouldRefresh) {
                                        if (shouldRefresh == true) _loadPresets();
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Add New Preset', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: dfNavyIndigo,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ---------------------------------------------------------------
                  // Settings Section
                  // ---------------------------------------------------------------
                  const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  
                  // Google Calendar
                  _InteractivePill(
                    onTap: _isSigningIn ? () {} : (_isCalendarConnected ? _handleCalendarSignOut : _handleCalendarSignIn),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6), 
                        borderRadius: BorderRadius.circular(cardBorderRadius), 
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: subtleShadow
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: (_isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey).withOpacity(0.1), shape: BoxShape.circle),
                            child: _isSigningIn
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(accentThemeColor)))
                              : Icon(_isCalendarConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: _isCalendarConnected ? Colors.green.shade600 : secondaryTextGrey, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Google Calendar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryTextDark)),
                                const SizedBox(height: 4),
                                Text(_isCalendarConnected ? 'Connected' : 'Not connected', style: const TextStyle(fontSize: 13, color: secondaryTextGrey, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: secondaryTextGrey, size: 22),
                        ],
                      ),
                    ),
                  ),

                  _buildSettingsItem(
                    icon: Icons.security_rounded, 
                    label: 'Privacy', 
                    onTap: () => _showPrivacyBottomSheet(context)
                  ),
                  _buildSettingsItem(
                    icon: Icons.help_outline_rounded, 
                    label: 'Help & Support', 
                    onTap: () => _showSupportBottomSheet(context)
                  ),
                  _buildSettingsItem(
                    icon: Icons.logout_rounded, 
                    label: 'Sign Out', 
                    textColor: errorIndicatorRed, 
                    onTap: handleSignOut
                  ),
                  
                  const SizedBox(height: 40),
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
// HELPER CLASSES & COMPONENTS 
// =============================================================================

class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractivePill({required this.child, required this.onTap});
  
  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  bool _isPressed = false;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0, 
        duration: const Duration(milliseconds: 150), 
        curve: Curves.easeOutCubic, 
        child: widget.child
      ),
    );
  }
}