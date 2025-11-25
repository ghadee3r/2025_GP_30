// ============================================================================
// FILE: SetSession.dart
// PURPOSE: Session configuration page with BLE device connection
// REDESIGNED: Matching Home theme with improved hardware connection clarity
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '/services/rikaz_light_service.dart';
import '/widgets/rikaz_device_picker.dart';
import '/main.dart';

// =============================================================================
// THEME DEFINITIONS - Matching Home Page
// =============================================================================

// Primary color palette (matching HomePage)
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

// Primary theme colors
const Color primaryThemeColor = dfDeepTeal;      // CHANGED: Now using dfDeepTeal
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

enum SessionMode { pomodoro, custom }

// Sound option model
class SoundOption {
  final String id;
  final String name;
  final String? filePathUrl;
  final String iconName;
  final String colorHex;

  SoundOption({
    required this.id,
    required this.name,
    required this.filePathUrl,
    required this.iconName,
    required this.colorHex,
  });

  factory SoundOption.off() {
    return SoundOption(
      id: 'off',
      name: 'No Sound',
      filePathUrl: null,
      iconName: 'volume_off_rounded',
      colorHex: '#6B6B78',
    );
  }

  IconData get icon {
    switch (iconName) {
      case 'water_drop_outlined':
        return Icons.water_drop_outlined;
      case 'water_rounded':
        return Icons.water_rounded;
      case 'waves_rounded':
        return Icons.waves_rounded;
      case 'volume_off_rounded':
        return Icons.volume_off_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}


// =============================================================================
// SET SESSION PAGE
// =============================================================================

class SetSessionPage extends StatefulWidget {
  final SessionMode? initialMode;

  const SetSessionPage({super.key, this.initialMode});

  @override
  State<SetSessionPage> createState() => _SetSessionPageState();
}

class _SetSessionPageState extends State<SetSessionPage> with SingleTickerProviderStateMixin {
  // --- SESSION MODE STATE ---
  late SessionMode sessionMode;

  // Pomodoro configuration
  String pomodoroDuration = '25min';
  double numberOfBlocks = 4;

  // Custom session configuration
  double customDuration = 70;

  // --- CONFIGURATION STATE ---
  // These are saved to database and sent to session page
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';
  
  // UI state for configuration menu (kept for future use)
  bool isConfigurationOpen = false;
  
  // --- SOUND SELECTION STATE ---
  SoundOption _selectedSound = SoundOption.off();
  List<SoundOption> _availableSounds = [];
  bool _soundsLoaded = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _previewTimer;

  // --- RIKAZ BLE CONNECTION STATE ---
  bool get isRikazToolConnected => RikazConnectionState.isConnected;
  bool isLoading = false; // Scanning/connecting in progress
  bool _showRikazConfirmation = false; // Show success message after connection

  // --- BLE CONNECTION MONITORING ---
  String? _connectedDeviceName;
  Timer? _connectionCheckTimer;
  bool _deviceWasConnected = false;
  bool _hasShownDisconnectWarning = false;

  // Slider reset key
  final GlobalKey<SlideActionState> _slideKey = GlobalKey<SlideActionState>();

  @override
  void initState() {
    super.initState();
    sessionMode = widget.initialMode ?? SessionMode.pomodoro;
    
    // Removed pulse animation controller - no longer needed
    
    // Load available sounds
    _loadSounds();
    
    // Restore connection state if already connected
    if (RikazConnectionState.isConnected) {
      debugPrint('🔌 Restored connection state from previous session');
      isConfigurationOpen = true;
      _startConnectionMonitoring();
    }
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    // Removed pulse controller disposal - no longer used
    _previewTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Load sounds from database
  Future<void> _loadSounds() async {
    try {
      final supabase = sb.Supabase.instance.client;
      final response = await supabase
          .from('Sound_Option')
          .select('sound_name, sound_file_path, icon_name, color_hex');

      final List<SoundOption> fetchedSounds = [SoundOption.off()];

      for (var item in response) {
        fetchedSounds.add(SoundOption(
          id: item['sound_name'],
          name: item['sound_name'],
          filePathUrl: item['sound_file_path'],
          iconName: item['icon_name'],
          colorHex: item['color_hex'],
        ));
      }

      if (mounted) {
        setState(() {
          _availableSounds = fetchedSounds;
          _soundsLoaded = true;
        });
      }
    } catch (e) {
      print('❌ Error fetching sounds: $e');
      if (mounted) {
        setState(() {
          _availableSounds = [SoundOption.off()];
          _soundsLoaded = true;
        });
      }
    }
  }
  
  // Play 5-second preview of selected sound
  Future<void> _playPreview(SoundOption sound) async {
    _previewTimer?.cancel();
    await _audioPlayer.stop();
    
    if (sound.id == 'off' || sound.filePathUrl == null) {
      return;
    }
    
    try {
      // Play immediately
      await _audioPlayer.play(UrlSource(sound.filePathUrl!));
      print('🎵 Playing preview: ${sound.name}');
      
      // Stop after exactly 5 seconds
      _previewTimer = Timer(const Duration(seconds: 5), () async {
        await _audioPlayer.stop();
        print('⏹️ Preview stopped after 5 seconds');
      });
    } catch (e) {
      print('❌ Error playing sound preview: $e');
    }
  }

  // Adaptive font sizing for different screen sizes
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final mitigationFactor = 0.9; 
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

  // Handle session start button press
  void handleStartSessionPress() {
    // Show friendly reminder if hardware is not connected, but allow proceeding
    if (!isRikazToolConnected) {
      _showHardwareReminderDialog();
      return;
    }
    
    // Warn if device was connected but is now unplugged
    if (_deviceWasConnected && !isRikazToolConnected && _hasShownDisconnectWarning) {
      showDialog(
        context: context,
        builder: (context) => _buildThemedDialog(
          title: 'Device Unplugged',
          content: 'Rikaz Tools device appears to be unplugged.\n\nThe session will start without hardware control. Plug in the device to enable lights.',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange.shade600,
          cancelText: 'Cancel',
          confirmText: 'Start Anyway',
          onConfirm: _navigateToSession,
        ),
      );
      return;
    }
    
    _navigateToSession();
  }
  
  // Show friendly reminder about hardware connection (but allow user to proceed)
  void _showHardwareReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Hardware Not Connected',
        content: 'You haven\'t connected your Rikaz Tools hardware yet.\n\nConnecting enables:\n• Smart light feedback\n• Screen monitoring\n\nYou can still start the session without it.',
        icon: Icons.lightbulb_outline,
        iconColor: accentThemeColor,
        cancelText: 'Connect Now',
        confirmText: 'Continue Anyway',
        onCancel: () {
          Navigator.pop(context);
          // User can scroll up to connect
        },
        onConfirm: _navigateToSession,
      ),
    );
  }
  
  // Helper widget for feature list in dialog
  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.008),
      child: Row(
        children: [
          Icon(icon, color: accentThemeColor, size: _adaptiveFontSize(0.045)),
          SizedBox(width: MediaQuery.of(context).size.width * 0.02),
          Text(
            text,
            style: TextStyle(
              fontSize: _adaptiveFontSize(0.032),
              color: primaryTextDark,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build themed dialog widget for consistent styling
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
                fontSize: _adaptiveFontSize(0.045),
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
                fontSize: _adaptiveFontSize(0.035),
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
                        fontSize: _adaptiveFontSize(0.035),
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
                        fontSize: _adaptiveFontSize(0.035),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ]),
    ));
  }
  
  // Navigate to session page with configuration
  void _navigateToSession() {
    final String sessionType = sessionMode == SessionMode.pomodoro ? 'pomodoro' : 'custom';
    final String durationValue = sessionMode == SessionMode.pomodoro ? pomodoroDuration : customDuration.toInt().toString();
    final String? blocks = sessionMode == SessionMode.pomodoro ? numberOfBlocks.toInt().toString() : null;

    // Stop any preview playing
    _previewTimer?.cancel();
    _audioPlayer.stop();

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': sessionType,
        'duration': durationValue,
        'numberOfBlocks': blocks,
        'isCameraDetectionEnabled': isCameraDetectionEnabled,
        'sensitivity': sensitivity,
        'notificationStyle': notificationStyle,
        'rikazConnected': RikazConnectionState.isConnected,
        'selectedSoundId': _selectedSound.id,
        'selectedSoundName': _selectedSound.name,
        'selectedSoundUrl': _selectedSound.filePathUrl,
      },
    );
  }

  // =============================================================================
  // BLE CONNECTION HANDLING
  // =============================================================================

  // Show device picker and establish BLE connection
  Future<void> _handleRikazConnect() async {
    if (RikazConnectionState.isConnected) return;

    setState(() => isLoading = true);

    // Show device picker dialog
    final RikazDevice? selectedDevice = await showDialog<RikazDevice>( 
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(), 
    );

    if (!mounted) return;

    if (selectedDevice != null) {
      // Connection successful
      RikazConnectionState.setConnected(true);
      _connectedDeviceName = selectedDevice.name;
      
      setState(() {
        isLoading = false;
        _showRikazConfirmation = true;
      });
      
      print('✅ Rikaz Tools: Connected to ${selectedDevice.name}');
      
      // Start monitoring BLE connection
      _startConnectionMonitoring();
      
      // Show success message briefly, then expand configuration
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _showRikazConfirmation = false;
          isConfigurationOpen = true;
        });
      }
    } else {
      // User cancelled or connection failed
      setState(() {
        isLoading = false;
      });
      
      // Reset slider animation
      try {
        if (_slideKey.currentState != null && mounted) {
          _slideKey.currentState!.reset();
        }
      } catch (e) {
        debugPrint('Slider reset error (safe to ignore): $e');
      }
    }
  }

  // Monitor BLE connection health
  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _deviceWasConnected = true;
    _hasShownDisconnectWarning = false;
    
    // Check connection every 5 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || !RikazConnectionState.isConnected) {
        timer.cancel();
        return;
      }
      
      final bool stillConnected = await RikazLightService.isConnected();
      
      if (!stillConnected) {
        // Connection lost
        timer.cancel();
        
        await RikazLightService.disconnect();
        RikazConnectionState.reset();

        if (mounted) {
          setState(() {
            isConfigurationOpen = false;
            _connectedDeviceName = null;
            _deviceWasConnected = false; 
          });
        }
        
        _showDeviceLostWarning();
        
      } else if (stillConnected && !_deviceWasConnected) {
        // Device reconnected
        _deviceWasConnected = true;
        _showDeviceReconnectedNotification();
      }
    });
  }

  // Show warning when BLE connection is lost
  void _showDeviceLostWarning() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildThemedDialog(
        title: 'Hardware Disconnected',
        content: 'The Bluetooth connection to your Rikaz device was lost.\n\nThis could be due to:\n• Device unplugged\n• Out of range\n• Low battery\n\nPlease check your device and try reconnecting.',
        icon: Icons.bluetooth_disabled_rounded,
        iconColor: errorIndicatorRed,
        cancelText: 'Close',
        confirmText: 'Reconnect Now',
        onConfirm: _handleRikazConnect,
      ),
    );
    
    debugPrint('⚠️ RIKAZ: Connection lost. Resetting global state.');
  }

  // Show notification when device reconnects
  void _showDeviceReconnectedNotification() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('Rikaz device reconnected! Hardware features active.'),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    debugPrint('✅ RIKAZ: Device reconnected');
  }

  // Handle manual disconnect
  Future<void> _handleRikazDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Disconnect Hardware?',
        content: 'This will disable hardware features (lights and monitoring) for your sessions.\n\nYou can reconnect anytime.',
        icon: Icons.power_settings_new_rounded,
        iconColor: errorIndicatorRed,
        cancelText: 'Cancel',
        confirmText: 'Disconnect',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () {
          Navigator.pop(context, true);
        },
      ),
    );

    if (confirmed == true) {
      _connectionCheckTimer?.cancel();
      
      // Turn off light and disconnect BLE
      await RikazLightService.turnOff(); 
      await RikazLightService.disconnect(); 
      
      RikazConnectionState.reset();
      
      setState(() {
        isConfigurationOpen = false;
        _connectedDeviceName = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hardware disconnected'),
            backgroundColor: primaryThemeColor,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      debugPrint('🔌 Rikaz Tools: Disconnected by user');
    }
  }

  // =============================================================================
  // UI COMPONENTS
  // =============================================================================
  
  // Helper widget for circular buttons (used in block counter)
  Widget _buildCircularIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required double size,
    Color buttonColor = accentThemeColor, 
  }) {
    final adjustedSize = size * 0.75; // Smaller buttons

    return Container(
      width: adjustedSize,
      height: adjustedSize,
      decoration: BoxDecoration(
        color: onPressed != null ? buttonColor : secondaryTextGrey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon, 
          color: onPressed != null ? Colors.white : secondaryTextGrey.withOpacity(0.5), 
          size: adjustedSize * 0.45,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // Pomodoro Block Counter
  Widget _pomodoroBlocksCounter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: accentThemeColor, 
              size: _adaptiveFontSize(0.05),
            ),
            SizedBox(width: screenWidth * 0.02),
            Text(
              'Number of Blocks',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.04),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        
        // Counter Buttons and Display
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.01),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(color: secondaryTextGrey.withOpacity(0.25), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Decrease Button
              _buildCircularIconButton(
                icon: Icons.remove_rounded,
                onPressed: numberOfBlocks > 1 ? () => setState(() => numberOfBlocks--) : null,
                color: accentThemeColor,
                size: screenWidth * 0.12, 
                buttonColor: accentThemeColor, 
              ),
              
              // Number Display - Less bold
              Text(
                numberOfBlocks.toInt().toString(),
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.18),
                  fontWeight: FontWeight.w700, // Reduced from w900
                  color: primaryTextDark, 
                  height: 1.1,
                ),
              ),
              
              // Increase Button
              _buildCircularIconButton(
                icon: Icons.add_rounded,
                onPressed: numberOfBlocks < 8 ? () => setState(() => numberOfBlocks++) : null,
                color: accentThemeColor,
                size: screenWidth * 0.12, 
                buttonColor: accentThemeColor, 
              ),
            ],
          ),
        ),
        
        SizedBox(height: screenHeight * 0.015),
        
        // Info text
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.01),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.038),
              ),
              SizedBox(width: screenWidth * 0.015),
              Expanded(
                child: Text(
                  'One block = focus session + break',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.031),
                    color: secondaryTextGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Pomodoro Settings
  Widget _buildPomodoroSettingsVertical() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Duration Options Section ---
        Text(
          'Duration Options',
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.04),
            fontWeight: FontWeight.bold,
            color: primaryTextDark,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        _pomodoroDurationOption('25min', '+ 5 min break'),
        _pomodoroDurationOption('50min', '+ 10 min break'),

        SizedBox(height: screenHeight * 0.025),
        
        // --- Blocks Counter Section ---
        _pomodoroBlocksCounter(),
      ],
    );
  }

  // Build hardware status visual with icons - SMALLER ICONS
  Widget _buildHardwareStatusVisual() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.02, // Reduced from 0.03
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRikazToolConnected 
              ? [
                  accentThemeColor.withOpacity(0.15),
                  lightestAccentColor.withOpacity(0.1),
                ]
              : [
                  secondaryTextGrey.withOpacity(0.08),
                  secondaryTextGrey.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: isRikazToolConnected 
              ? accentThemeColor.withOpacity(0.4)
              : secondaryTextGrey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildHardwareIcon(
            icon: Icons.lightbulb_rounded,
            label: 'Smart Light',
            isActive: isRikazToolConnected,
          ),
          Container(
            width: 1.5,
            height: screenHeight * 0.05, // Reduced from 0.08
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  secondaryTextGrey.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          _buildHardwareIcon(
            icon: Icons.computer_rounded,
            label: 'Screen Monitor',
            isActive: isRikazToolConnected,
          ),
        ],
      ),
    );
  }
  
  // Build individual hardware icon with status - NO PULSING
  Widget _buildHardwareIcon({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      children: [
        // Removed AnimatedBuilder and pulsing animation
        Container(
          padding: EdgeInsets.all(screenWidth * 0.03),
          decoration: BoxDecoration(
            gradient: isActive 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentThemeColor,
                      accentThemeColor.withOpacity(0.7),
                    ],
                  )
                : null,
            color: isActive ? null : secondaryTextGrey.withOpacity(0.15),
            shape: BoxShape.circle,
            boxShadow: isActive 
                ? [
                    BoxShadow(
                      color: accentThemeColor.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : secondaryTextGrey,
            size: screenWidth * 0.06,
          ),
        ),
        SizedBox(height: screenHeight * 0.008),
        Text(
          label,
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.028),
            fontWeight: FontWeight.w600,
            color: isActive ? accentThemeColor : secondaryTextGrey,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // Rikaz BLE connection section
  Widget _buildRikazConnect() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      margin: EdgeInsets.only(bottom: screenHeight * 0.025), 
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isRikazToolConnected ? Icons.check_circle : Icons.bluetooth,
                color: isRikazToolConnected ? Colors.green.shade600 : accentThemeColor, // CHANGED
                size: _adaptiveFontSize(0.055),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Text(
                  isRikazToolConnected ? 'Hardware Connected' : 'Connect Hardware',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.045),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                ),
              ),
              if (isRikazToolConnected && !_showRikazConfirmation)
                IconButton(
                  icon: Icon(Icons.power_settings_new, color: errorIndicatorRed),
                  onPressed: _handleRikazDisconnect,
                  tooltip: 'Disconnect',
                ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          
          // Hardware status visual
          _buildHardwareStatusVisual(),
          SizedBox(height: screenHeight * 0.015),
          
          // Status message or connection slider
          if (_showRikazConfirmation) ...[
            // Success confirmation
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: _adaptiveFontSize(0.06)),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connection Successful!',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.04),
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          'All hardware features are now active',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.032),
                            color: secondaryTextGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isRikazToolConnected) ...[
            // Connected status
            Text(
              'Your Rikaz Tools hardware is ready. All features are enabled and monitoring your focus session.',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.033),
                color: secondaryTextGrey,
                height: 1.4,
              ),
            ),
          ] else ...[
            // Not connected - show slider
            Text(
              'Connect your Rikaz Tools hardware via Bluetooth to enable smart light control, screen monitoring, and camera detection.',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.033),
                color: secondaryTextGrey,
                height: 1.4,
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            SlideAction(
              key: _slideKey,
              text: isLoading ? "Scanning..." : "Slide to Connect",
              textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.038),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              innerColor: cardBackground,
              outerColor: accentThemeColor,
              sliderButtonIcon: Container(
                decoration: BoxDecoration(
                  color: cardBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bluetooth_searching,
                  color: accentThemeColor,
                  size: screenWidth * 0.06,
                ),
              ),
              sliderButtonIconPadding: 12,
              height: screenHeight * 0.065, 
              borderRadius: cardBorderRadius,
              onSubmit: isLoading ? null : () async {
                await _handleRikazConnect();
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  // Pomodoro duration option (25min or 50min)
  Widget _pomodoroDurationOption(String label, String breakText) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = pomodoroDuration == label;

    return GestureDetector(
      onTap: () => setState(() => pomodoroDuration = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: screenHeight * 0.012),
        padding: EdgeInsets.all(screenWidth * 0.045),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(cardBorderRadius / 1.5),
          border: Border.all(
            color: isSelected ? accentThemeColor : secondaryTextGrey.withOpacity(0.25), 
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Checkmark icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: screenWidth * 0.065,
              height: screenWidth * 0.065,
              decoration: BoxDecoration(
                color: isSelected ? accentThemeColor : Colors.transparent, 
                shape: BoxShape.circle,
                border: isSelected 
                    ? null 
                    : Border.all(color: secondaryTextGrey.withOpacity(0.4), width: 2),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, color: Colors.white, size: screenWidth * 0.04)
                  : null,
            ),
            SizedBox(width: screenWidth * 0.04),
            
            // Duration text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.042),
                      fontWeight: FontWeight.bold,
                      color: isSelected ? accentThemeColor : primaryTextDark, 
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    breakText,
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.031),
                      color: secondaryTextGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom duration slider
  Widget _customDurationSlider() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.025),
              decoration: BoxDecoration(
                color: accentThemeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.05),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Text(
              'Session Duration',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.04),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.025),
        
        // Large time display - CLEANER
        Center(
          child: Column(
            children: [
              Text(
                '${customDuration.toInt()}',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.22), // Larger
                  fontWeight: FontWeight.w700, // Less bold
                  color: primaryTextDark,
                  height: 1,
                ),
              ),
              SizedBox(height: screenHeight * 0.005),
              Text(
                'minutes',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.038),
                  fontWeight: FontWeight.w500,
                  color: secondaryTextGrey,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        
        // "No Breaks" badge
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.008,
            ),
            decoration: BoxDecoration(
              color: secondaryTextGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: secondaryTextGrey.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block_rounded,
                  color: secondaryTextGrey,
                  size: _adaptiveFontSize(0.035),
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  'No Breaks',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.032),
                    fontWeight: FontWeight.w600,
                    color: secondaryTextGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.025),
        
        // Slider - CIRCULAR THUMB
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentThemeColor, 
            inactiveTrackColor: lightestAccentColor.withOpacity(0.5),
            thumbColor: accentThemeColor,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14, // Circular thumb
              elevation: 3,
            ),
            overlayColor: accentThemeColor.withOpacity(0.2), 
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
            trackHeight: 6,
          ),
          child: Slider(
            value: customDuration,
            min: 25,
            max: 120,
            divisions: (120 - 25),
            label: '${customDuration.toInt()} min',
            onChanged: (v) => setState(() => customDuration = v),
          ),
        ),
        
        // Min-Max labels
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '25 min',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.028),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '120 min',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.028),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        
        // Info text with icon
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: accentThemeColor,
              size: _adaptiveFontSize(0.04),
            ),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: Text(
                'Continuous focus without interruptions',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.031),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Session mode toggle
  Widget _buildModeToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenHeight * 0.005),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 184, 184, 184).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleButton(SessionMode.pomodoro, 'Pomodoro', Icons.timer),
          SizedBox(width: screenWidth * 0.02),
          _toggleButton(SessionMode.custom, 'Custom Focus', Icons.tune),
        ],
      ),
    );
  }

  // Mode toggle button - CHANGED TO dfDeepTeal
  Widget _toggleButton(SessionMode mode, String text, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = sessionMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => sessionMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
          decoration: BoxDecoration(
            color: isSelected ? dfDeepTeal : Colors.transparent, // CHANGED
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
                ? [BoxShadow(color: dfDeepTeal.withOpacity(0.3), blurRadius: 8)] // CHANGED
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: screenWidth * 0.05,
                color: isSelected ? Colors.white : secondaryTextGrey,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                text,
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.035),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : secondaryTextGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Sound selection section - DROPDOWN WITH CLEAR COLORS
  Widget _buildSoundSelection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define clear colors for sound options
    final Map<String, Color> soundColors = {
      'off': secondaryTextGrey,
      'default': Color.fromARGB(255, 48, 139, 117), // Clear blue
      'Rain': Color(0xFF5DADE2),    // Sky blue

  
      'White Noise': Color.fromARGB(255, 186, 156, 241), // Light grey

    };

    Color getSoundColor(String soundName) {
      return soundColors[soundName] ?? soundColors['default']!;
    }

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.055),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Text(
                  'Background Sound',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.045),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            'Select a sound to play during your focus session',
            style: TextStyle(
              fontSize: _adaptiveFontSize(0.033),
              color: secondaryTextGrey,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Dropdown
          if (!_soundsLoaded)
            Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.02),
                child: CircularProgressIndicator(color: accentThemeColor),
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.005,
              ),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentThemeColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSound.id,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: accentThemeColor,
                    size: screenWidth * 0.07,
                  ),
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04),
                    fontWeight: FontWeight.w600,
                    color: primaryTextDark,
                  ),
                  dropdownColor: cardBackground,
                  onChanged: (String? newSoundId) {
                    if (newSoundId != null) {
                      final newSound = _availableSounds.firstWhere(
                        (s) => s.id == newSoundId,
                        orElse: () => SoundOption.off(),
                      );
                      setState(() {
                        _selectedSound = newSound;
                      });
                      _playPreview(newSound);
                    }
                  },
                  items: _availableSounds.map<DropdownMenuItem<String>>((SoundOption sound) {
                    final soundColor = getSoundColor(sound.name);
                    
                    return DropdownMenuItem<String>(
                      value: sound.id,
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            decoration: BoxDecoration(
                              color: soundColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              sound.icon,
                              color: soundColor,
                              size: screenWidth * 0.05,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: Text(
                              sound.name,
                              style: TextStyle(
                                fontSize: _adaptiveFontSize(0.04),
                                fontWeight: FontWeight.w600,
                                color: primaryTextDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          
          // Preview indicator
          if (_soundsLoaded && _selectedSound.id != 'off')
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.015),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: accentThemeColor,
                    size: _adaptiveFontSize(0.04),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    '5-second preview will play on selection',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.03),
                      color: secondaryTextGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // =============================================================================
  // MAIN BUILD
  // =============================================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final proportionalHorizontalPadding = screenWidth * 0.05;

    final bool isStartButtonEnabled = !isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Set Session',
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.045),
            fontWeight: FontWeight.bold,
            color: primaryTextDark,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: proportionalHorizontalPadding,
                right: proportionalHorizontalPadding,
                top: screenHeight * 0.02,
                bottom: screenHeight * 0.2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page title
                  Text(
                    sessionMode == SessionMode.pomodoro 
                        ? 'Pomodoro Session' 
                        : 'Custom Session',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.055),
                      fontWeight: FontWeight.w800,
                      color: primaryTextDark,
                    ),
                  ),
                  Text(
                    sessionMode == SessionMode.pomodoro
                        ? 'Structured focus and break sessions'
                        : 'Set your own uninterrupted timing',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.035),
                      color: secondaryTextGrey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.025),

                  // Session mode toggle
                  _buildModeToggle(),
                  SizedBox(height: screenHeight * 0.025),

                  // Rikaz BLE connection section with visuals
                  _buildRikazConnect(),

                  // Session configuration
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (sessionMode == SessionMode.pomodoro)
                        ? Column(
                            key: const ValueKey(SessionMode.pomodoro),
                            children: [
                              _buildPomodoroSettingsVertical(),
                            ],
                          )
                        : Column(
                            key: const ValueKey(SessionMode.custom),
                            children: [_customDurationSlider()],
                          ),
                  ),

                  SizedBox(height: screenHeight * 0.025),
                  
                  // Sound selection section
                  _buildSoundSelection(),
                ],
              ),
            ),

            // Sticky start button at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryBackground,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: proportionalHorizontalPadding,
                  right: proportionalHorizontalPadding,
                  top: screenHeight * 0.02,
                  bottom: screenHeight * 0.03,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Friendly reminder when hardware is offline
                    if (!isRikazToolConnected)
                      Container(
                        margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentThemeColor.withOpacity(0.1),
                              lightestAccentColor.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentThemeColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: accentThemeColor,
                              size: _adaptiveFontSize(0.045),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Expanded(
                              child: Text(
                                'Connect hardware for enhanced features',
                                style: TextStyle(
                                  fontSize: _adaptiveFontSize(0.032),
                                  color: primaryTextDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Start session button - CHANGED TO dfDeepTeal
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isStartButtonEnabled ? handleStartSessionPress : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dfDeepTeal, // CHANGED
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.022),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(cardBorderRadius),
                          ),
                          elevation: 6,
                          shadowColor: dfDeepTeal.withOpacity(0.4), // CHANGED
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: _adaptiveFontSize(0.06)),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              'Start Session',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _adaptiveFontSize(0.04),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}