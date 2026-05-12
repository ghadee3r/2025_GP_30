import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../subscreens/create_preset.dart'; 

// =============================================================================
// THEME DEFINITIONS (Synchronized with Progress & Home Page)
// =============================================================================
const Color dfDeepBlue = Color(0xFF7E84D4);
const Color dfDeepTeal = Color(0xFF1B2536); 
const Color dfTealCyan = Color(0xFF68C29D); 
const Color customModeColor = Color(0xFF7E84D4); 
const Color dfSoftPink = Color(0xFFF08A8D); 
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
    try {
      await supabase.from('Preset').delete().eq('Preset_id', presetId);
      _showSuccessSnackBar('Preset deleted');
      _loadPresets(); 
    } catch (e) {
      _showErrorSnackBar('Failed to delete preset: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]), 
      backgroundColor: errorIndicatorRed, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
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

  void _showPresetOptionsModal(Map<String, dynamic> preset) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text(preset['preset_name'] ?? 'Preset Options', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
            const SizedBox(height: 24),
            _InteractivePill(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePresetPage(presetToEdit: preset))).then((shouldRefresh) {
                  if (shouldRefresh == true) _loadPresets();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), 
                child: Row(children: const [Icon(Icons.tune_rounded, color: dfTealCyan), SizedBox(width: 16), Text('Edit Preset', style: TextStyle(color: dfTealCyan, fontWeight: FontWeight.w600, fontSize: 15))])
              ),
            ),
            const SizedBox(height: 12),
            _InteractivePill(
              onTap: () {
                Navigator.pop(context);
                _deletePreset(preset['Preset_id'].toString());
              },
              child: Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), 
                child: Row(children: const [Icon(Icons.delete_outline_rounded, color: errorIndicatorRed), SizedBox(width: 16), Text('Delete Preset', style: TextStyle(color: errorIndicatorRed, fontWeight: FontWeight.w600, fontSize: 15))])
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSettingsItem({required IconData icon, required String label, required VoidCallback onTap, Color? iconColor, Color? textColor}) {
    return _InteractivePill(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? secondaryTextGrey, size: 24),
            const SizedBox(width: 20),
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor ?? primaryTextDark))),
            Icon(Icons.chevron_right_rounded, color: secondaryTextGrey.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection() {
    bool isMaxReached = _userPresets.length >= _maxPresetsLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // Thinned out the header font weight!
                Text('Presets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: dfNavyIndigo, letterSpacing: -0.5)),
                SizedBox(height: 4),
              ],
            ),
            _InteractivePill(
              onTap: () {
                if (isMaxReached) {
                  _showErrorSnackBar('You can only make 5 presets, delete a preset to create a new one, or edit an existing preset.');
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePresetPage())).then((shouldRefresh) {
                    if (shouldRefresh == true) _loadPresets();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isMaxReached ? Colors.grey.shade200 : dfTealCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isMaxReached ? Colors.grey.shade300 : dfTealCyan.withOpacity(0.3), width: 1.5),
                ),
                child: Text('+ New', style: TextStyle(color: isMaxReached ? secondaryTextGrey : dfTealCyan, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),

        if (_isLoadingPresets)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: accentThemeColor)))
        else if (_userPresets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Text('No presets saved yet. Create one to get started.', style: TextStyle(color: secondaryTextGrey.withOpacity(0.8), fontSize: 14)),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userPresets.length,
            itemBuilder: (context, index) {
              final preset = _userPresets[index];
              
              final activeTriggers = <String>[];
              if (preset['trigger_phone_use'] == true) activeTriggers.add('phone');
              if (preset['trigger_sleeping'] == true) activeTriggers.add('sleeping');
              if (preset['trigger_absence'] == true) activeTriggers.add('absence');

              final colors = [dfTealCyan, customModeColor, dfSoftPink];
              final themeColor = colors[index % colors.length];

              return _InteractivePill(
                onTap: () => _showPresetOptionsModal(preset),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(cardBorderRadius),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: subtleShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: themeColor.withOpacity(0.15), width: 1)),
                        child: Center(
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: themeColor.withOpacity(0.3), width: 1)),
                            child: Center(
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor),
                              )
                            )
                          )
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preset['preset_name'] ?? 'Unnamed', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dfNavyIndigo, letterSpacing: -0.3)),
                            if (activeTriggers.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: activeTriggers.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: dfNavyIndigo.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(t, style: TextStyle(color: dfNavyIndigo.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w700)),
                                )).toList(),
                              )
                            ]
                          ],
                        ),
                      ),
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
                          color: themeColor.withOpacity(0.05),
                        ),
                        child: Icon(Icons.more_horiz_rounded, color: themeColor, size: 20),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
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
                  const SizedBox(height: 40),

                  // ---------------------------------------------------------------
                  // Minimalist Header (Avatar + Typography)
                  // ---------------------------------------------------------------
                  Row(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5), 
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U', 
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: dfNavyIndigo)
                          )
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.normal, color: dfNavyIndigo, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(userEmail, style: const TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ---------------------------------------------------------------
                  // PRESETS 
                  // ---------------------------------------------------------------
                  _buildPresetsSection(),

                  const SizedBox(height: 48),

                  // ---------------------------------------------------------------
                  // Minimalist Settings Section
                  // ---------------------------------------------------------------
                  const Text('SETTINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: secondaryTextGrey, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  
                  // Google Calendar (Flat style)
                  _InteractivePill(
                    onTap: _isSigningIn ? () {} : (_isCalendarConnected ? _handleCalendarSignOut : _handleCalendarSignIn),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          _isSigningIn
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(dfTealCyan)))
                              : Icon(_isCalendarConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: _isCalendarConnected ? dfTealCyan : secondaryTextGrey, size: 24),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Google Calendar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryTextDark)),
                                const SizedBox(height: 2),
                                Text(_isCalendarConnected ? 'Connected' : 'Not connected', style: TextStyle(fontSize: 13, color: secondaryTextGrey.withOpacity(0.8))),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: secondaryTextGrey.withOpacity(0.5), size: 20),
                        ],
                      ),
                    ),
                  ),

                  Divider(color: Colors.black.withOpacity(0.04), height: 1),

                  _buildSettingsItem(
                    icon: Icons.security_rounded, 
                    label: 'Privacy', 
                    onTap: () => _showPrivacyBottomSheet(context)
                  ),
                  
                  Divider(color: Colors.black.withOpacity(0.04), height: 1),

                  _buildSettingsItem(
                    icon: Icons.help_outline_rounded, 
                    label: 'Help & Support', 
                    onTap: () => _showSupportBottomSheet(context)
                  ),

                  Divider(color: Colors.black.withOpacity(0.04), height: 1),

                  _buildSettingsItem(
                    icon: Icons.logout_rounded, 
                    label: 'Sign Out', 
                    iconColor: errorIndicatorRed,
                    textColor: errorIndicatorRed, 
                    onTap: handleSignOut
                  ),
                  
                  const SizedBox(height: 60), 
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