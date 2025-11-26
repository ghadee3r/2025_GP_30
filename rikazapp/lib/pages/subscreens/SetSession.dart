// ============================================================================
// FILE: SetSession.dart
// PURPOSE: Session configuration page with BLE device connection
// REDESIGNED: Elegant, comfortable spacing with downsized elements
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
const double cardBorderRadius = 14.0; // Slightly reduced

// Standard shadow for elevated cards
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.06), // Softer shadow
        blurRadius: 8,
        offset: const Offset(0, 4),
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
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';
  
  bool isConfigurationOpen = false;
  
  // --- SOUND SELECTION STATE ---
  SoundOption _selectedSound = SoundOption.off();
  List<SoundOption> _availableSounds = [];
  bool _soundsLoaded = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _previewTimer;

  // --- RIKAZ BLE CONNECTION STATE ---
  bool get isRikazToolConnected => RikazConnectionState.isConnected;
  bool isLoading = false;
  bool _showRikazConfirmation = false;

  // --- BLE CONNECTION MONITORING ---
  String? _connectedDeviceName;
  Timer? _connectionCheckTimer;
  bool _deviceWasConnected = false;
  bool _hasShownDisconnectWarning = false;

  final GlobalKey<SlideActionState> _slideKey = GlobalKey<SlideActionState>();

  @override
  void initState() {
    super.initState();
    sessionMode = widget.initialMode ?? SessionMode.pomodoro;
    _loadSounds();
    
    if (RikazConnectionState.isConnected) {
      debugPrint('🔌 Restored connection state from previous session');
      isConfigurationOpen = true;
      _startConnectionMonitoring();
    }
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
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
      await _audioPlayer.play(UrlSource(sound.filePathUrl!));
      print('🎵 Playing preview: ${sound.name}');
      
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
    if (!isRikazToolConnected) {
      _showHardwareReminderDialog();
      return;
    }
    
    if (_deviceWasConnected && !isRikazToolConnected && _hasShownDisconnectWarning) {
      showDialog(
        context: context,
        builder: (context) => _buildThemedDialog(
          title: 'Device Unplugged',
          content: 'Rikaz Tools device appears to be unplugged.\n\nThe session will start without hardware control.',
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
  
  // Show friendly reminder about hardware connection
  void _showHardwareReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Hardware Not Connected',
        content: 'You haven\'t connected your Rikaz Tools hardware yet.',
        icon: Icons.lightbulb_outline,
        iconColor: accentThemeColor,
        cancelText: 'Connect Now',
        confirmText: 'Start Anyway',
        onCancel: () {
          Navigator.pop(context);
        },
        onConfirm: _navigateToSession,
      ),
    );
  }
  
  // Build themed dialog widget
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
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.045),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.035),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: MediaQuery.of(context).size.width * 0.10,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.018),
            
            Text(
              title,
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.042),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.012),
            
            Text(
              content,
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.032),
                color: secondaryTextGrey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.022),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel ?? () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.013,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: secondaryTextGrey.withOpacity(0.3)),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        color: secondaryTextGrey,
                        fontSize: _adaptiveFontSize(0.033),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.025),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onConfirm != null) onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryThemeColor,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.013,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _adaptiveFontSize(0.033),
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

  Future<void> _handleRikazConnect() async {
    if (RikazConnectionState.isConnected) return;

    setState(() => isLoading = true);

    final RikazDevice? selectedDevice = await showDialog<RikazDevice>( 
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(), 
    );

    if (!mounted) return;

    if (selectedDevice != null) {
      RikazConnectionState.setConnected(true);
      _connectedDeviceName = selectedDevice.name;
      
      setState(() {
        isLoading = false;
        _showRikazConfirmation = true;
      });
      
      print('✅ Rikaz Tools: Connected to ${selectedDevice.name}');
      
      _startConnectionMonitoring();
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _showRikazConfirmation = false;
          isConfigurationOpen = true;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
      
      try {
        if (_slideKey.currentState != null && mounted) {
          _slideKey.currentState!.reset();
        }
      } catch (e) {
        debugPrint('Slider reset error (safe to ignore): $e');
      }
    }
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _deviceWasConnected = true;
    _hasShownDisconnectWarning = false;
    
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || !RikazConnectionState.isConnected) {
        timer.cancel();
        return;
      }
      
      final bool stillConnected = await RikazLightService.isConnected();
      
      if (!stillConnected) {
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
        _deviceWasConnected = true;
        _showDeviceReconnectedNotification();
      }
    });
  }

  void _showDeviceLostWarning() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildThemedDialog(
        title: 'Hardware Disconnected',
        content: 'The Bluetooth connection to your Rikaz device was lost. Please check your device and try reconnecting.',
        icon: Icons.bluetooth_disabled_rounded,
        iconColor: errorIndicatorRed,
        cancelText: 'Close',
        confirmText: 'Reconnect Now',
        onConfirm: _handleRikazConnect,
      ),
    );
    
    debugPrint('⚠️ RIKAZ: Connection lost. Resetting global state.');
  }

  void _showDeviceReconnectedNotification() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('Rikaz device reconnected!'),
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

  Future<void> _handleRikazDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Disconnect Hardware?',
        content: 'This will disable hardware features for your sessions. You can reconnect anytime.',
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
  // UI COMPONENTS - ALL DOWNSIZED
  // =============================================================================
  
  Widget _buildCircularIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required double size,
    Color buttonColor = accentThemeColor, 
  }) {
    final adjustedSize = size * 0.7; // Even smaller

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
          size: adjustedSize * 0.42,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _pomodoroBlocksCounter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: accentThemeColor, 
              size: _adaptiveFontSize(0.045),
            ),
            SizedBox(width: screenWidth * 0.015),
            Text(
              'Number of Blocks',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.037),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.012),
        
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025, vertical: screenHeight * 0.008),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(color: secondaryTextGrey.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircularIconButton(
                icon: Icons.remove_rounded,
                onPressed: numberOfBlocks > 1 ? () => setState(() => numberOfBlocks--) : null,
                color: accentThemeColor,
                size: screenWidth * 0.11, 
                buttonColor: accentThemeColor, 
              ),
              
              Text(
                numberOfBlocks.toInt().toString(),
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.14),
                  fontWeight: FontWeight.w500,
                  color: primaryTextDark, 
                  height: 1.1,
                ),
              ),
              
              _buildCircularIconButton(
                icon: Icons.add_rounded,
                onPressed: numberOfBlocks < 8 ? () => setState(() => numberOfBlocks++) : null,
                color: accentThemeColor,
                size: screenWidth * 0.11, 
                buttonColor: accentThemeColor, 
              ),
            ],
          ),
        ),
        
        SizedBox(height: screenHeight * 0.012),
        
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.01),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.035),
              ),
              SizedBox(width: screenWidth * 0.012),
              Expanded(
                child: Text(
                  'One block = focus session + break',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.029),
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
  
  Widget _buildPomodoroSettingsVertical() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration Options',
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.037),
            fontWeight: FontWeight.bold,
            color: primaryTextDark,
          ),
        ),
        SizedBox(height: screenHeight * 0.012),
        _pomodoroDurationOption('25min', '+ 5 min break'),
        _pomodoroDurationOption('50min', '+ 10 min break'),

        SizedBox(height: screenHeight * 0.02),
        
        _pomodoroBlocksCounter(),
      ],
    );
  }

  Widget _buildHardwareStatusVisual() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRikazToolConnected 
              ? [
                  accentThemeColor.withOpacity(0.12),
                  lightestAccentColor.withOpacity(0.08),
                ]
              : [
                  secondaryTextGrey.withOpacity(0.06),
                  secondaryTextGrey.withOpacity(0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRikazToolConnected 
              ? accentThemeColor.withOpacity(0.3)
              : secondaryTextGrey.withOpacity(0.18),
          width: 1.2,
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
            width: 1.2,
            height: screenHeight * 0.04,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  secondaryTextGrey.withOpacity(0.15),
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
  
  Widget _buildHardwareIcon({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.025),
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
            color: isActive ? null : secondaryTextGrey.withOpacity(0.12),
            shape: BoxShape.circle,
            boxShadow: isActive 
                ? [
                    BoxShadow(
                      color: accentThemeColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : secondaryTextGrey,
            size: screenWidth * 0.052,
          ),
        ),
        SizedBox(height: screenHeight * 0.006),
        Text(
          label,
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.026),
            fontWeight: FontWeight.w600,
            color: isActive ? accentThemeColor : secondaryTextGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildRikazConnect() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      margin: EdgeInsets.only(bottom: screenHeight * 0.02), 
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
                isRikazToolConnected ? Icons.check_circle : Icons.bluetooth,
                color: isRikazToolConnected ? Colors.green.shade600 : accentThemeColor,
                size: _adaptiveFontSize(0.05),
              ),
              SizedBox(width: screenWidth * 0.015),
              Expanded(
                child: Text(
                  isRikazToolConnected ? 'Hardware Connected' : 'Connect Hardware',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                ),
              ),
              if (isRikazToolConnected && !_showRikazConfirmation)
                IconButton(
                  icon: Icon(Icons.power_settings_new, color: errorIndicatorRed, size: 20),
                  onPressed: _handleRikazDisconnect,
                  tooltip: 'Disconnect',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: screenHeight * 0.012),
          
          _buildHardwareStatusVisual(),
          SizedBox(height: screenHeight * 0.012),
          
          if (_showRikazConfirmation) ...[
            Container(
              padding: EdgeInsets.all(screenWidth * 0.035),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: _adaptiveFontSize(0.05)),
                  SizedBox(width: screenWidth * 0.025),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connection Successful!',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.037),
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.003),
                        Text(
                          'All hardware features are now active',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.03),
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
            Text(
              'Your Rikaz Tools hardware is ready and monitoring your focus session.',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.031),
                color: secondaryTextGrey,
                height: 1.3,
              ),
            ),
          ] else ...[
            
            SizedBox(height: screenHeight * 0.015),
            SlideAction(
              key: _slideKey,
              text: isLoading ? "Scanning..." : "Slide to Connect",
              textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.035),
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
                  size: screenWidth * 0.055,
                ),
              ),
              sliderButtonIconPadding: 10,
              height: screenHeight * 0.058, 
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

  Widget _pomodoroDurationOption(String label, String breakText) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = pomodoroDuration == label;

    return GestureDetector(
      onTap: () => setState(() => pomodoroDuration = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: screenHeight * 0.01),
        padding: EdgeInsets.all(screenWidth * 0.038),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentThemeColor : secondaryTextGrey.withOpacity(0.2), 
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: screenWidth * 0.058,
              height: screenWidth * 0.058,
              decoration: BoxDecoration(
                color: isSelected ? accentThemeColor : Colors.transparent, 
                shape: BoxShape.circle,
                border: isSelected 
                    ? null 
                    : Border.all(color: secondaryTextGrey.withOpacity(0.35), width: 1.8),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, color: Colors.white, size: screenWidth * 0.035)
                  : null,
            ),
            SizedBox(width: screenWidth * 0.035),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.039),
                      fontWeight: FontWeight.bold,
                      color: isSelected ? accentThemeColor : primaryTextDark, 
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.002),
                  Text(
                    breakText,
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.029),
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

  Widget _customDurationSlider() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.022),
              decoration: BoxDecoration(
                color: accentThemeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.045),
              ),
            ),
            SizedBox(width: screenWidth * 0.025),
            Text(
              'Session Duration',
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.037),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.02),
        
        Center(
          child: Column(
            children: [
              Text(
                '${customDuration.toInt()}',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.14),
                  fontWeight: FontWeight.w500,
                  color: primaryTextDark,
                  height: 1,
                ),
              ),
              SizedBox(height: screenHeight * 0.004),
              Text(
                'minutes',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.035),
                  fontWeight: FontWeight.w500,
                  color: secondaryTextGrey,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.012),
        
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.035,
              vertical: screenHeight * 0.006,
            ),
            decoration: BoxDecoration(
              color: secondaryTextGrey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: secondaryTextGrey.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block_rounded,
                  color: secondaryTextGrey,
                  size: _adaptiveFontSize(0.032),
                ),
                SizedBox(width: screenWidth * 0.012),
                Text(
                  'No Breaks',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.03),
                    fontWeight: FontWeight.w600,
                    color: secondaryTextGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentThemeColor, 
            inactiveTrackColor: lightestAccentColor.withOpacity(0.4),
            thumbColor: accentThemeColor,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              elevation: 2,
            ),
            overlayColor: accentThemeColor.withOpacity(0.18), 
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            trackHeight: 5,
          ),
          child: Slider(
            value: customDuration,
            min: 10,
            max: 120,
            divisions: (120 - 10),
            label: '${customDuration.toInt()} min',
            onChanged: (v) => setState(() => customDuration = v),
          ),
        ),
        
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.015),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10 min',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.026),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '120 min',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.026),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.012),
        
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: accentThemeColor,
              size: _adaptiveFontSize(0.037),
            ),
            SizedBox(width: screenWidth * 0.015),
            Expanded(
              child: Text(
                'Continuous focus without interruptions',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.029),
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

  Widget _buildModeToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenHeight * 0.004),
      decoration: BoxDecoration(
        color: secondaryTextGrey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _toggleButton(SessionMode.pomodoro, 'Pomodoro', Icons.timer),
          SizedBox(width: screenWidth * 0.015),
          _toggleButton(SessionMode.custom, 'Custom Focus', Icons.tune),
        ],
      ),
    );
  }

  Widget _toggleButton(SessionMode mode, String text, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = sessionMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => sessionMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.013),
          decoration: BoxDecoration(
            color: isSelected ? dfDeepTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
                ? [BoxShadow(color: dfDeepTeal.withOpacity(0.25), blurRadius: 6)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: screenWidth * 0.045,
                color: isSelected ? Colors.white : secondaryTextGrey,
              ),
              SizedBox(width: screenWidth * 0.015),
              Text(
                text,
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.033),
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
  
  Widget _buildSoundSelection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final Map<String, Color> soundColors = {
      'off': secondaryTextGrey,
      'default': Color.fromARGB(255, 48, 139, 117),
      'Rain': Color(0xFF5DADE2),
      'White Noise': Color.fromARGB(255, 186, 156, 241),
    };

    Color getSoundColor(String soundName) {
      return soundColors[soundName] ?? soundColors['default']!;
    }

    return Container(
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
                Icons.music_note_rounded,
                color: accentThemeColor,
                size: _adaptiveFontSize(0.05),
              ),
              SizedBox(width: screenWidth * 0.015),
              Expanded(
                child: Text(
                  'Background Sound',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.008),
          Text(
            'Select a sound to play during your focus session',
            style: TextStyle(
              fontSize: _adaptiveFontSize(0.031),
              color: secondaryTextGrey,
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          
          if (!_soundsLoaded)
            Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.015),
                child: CircularProgressIndicator(color: accentThemeColor, strokeWidth: 2.5),
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.035,
                vertical: screenHeight * 0.004,
              ),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: accentThemeColor.withOpacity(0.25),
                  width: 1.3,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSound.id,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: accentThemeColor,
                    size: screenWidth * 0.065,
                  ),
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.037),
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
                            padding: EdgeInsets.all(screenWidth * 0.018),
                            decoration: BoxDecoration(
                              color: soundColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              sound.icon,
                              color: soundColor,
                              size: screenWidth * 0.045,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.025),
                          Expanded(
                            child: Text(
                              sound.name,
                              style: TextStyle(
                                fontSize: _adaptiveFontSize(0.037),
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
          
          if (_soundsLoaded && _selectedSound.id != 'off')
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.012),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: accentThemeColor,
                    size: _adaptiveFontSize(0.037),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Expanded(
                    child: Text(
                      '5-second preview will play on selection',
                      style: TextStyle(
                        fontSize: _adaptiveFontSize(0.028),
                        color: secondaryTextGrey,
                        fontStyle: FontStyle.italic,
                      ),
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
    final proportionalHorizontalPadding = screenWidth * 0.06;

    final bool isStartButtonEnabled = !isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextDark, size: _adaptiveFontSize(0.055)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Set Session',
          style: TextStyle(
            fontSize: _adaptiveFontSize(0.042),
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
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: proportionalHorizontalPadding,
                right: proportionalHorizontalPadding,
                top: screenHeight * 0.015,
                bottom: screenHeight * 0.18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionMode == SessionMode.pomodoro 
                        ? 'Pomodoro Session' 
                        : 'Custom Session',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.048),
                      fontWeight: FontWeight.w700,
                      color: primaryTextDark,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    sessionMode == SessionMode.pomodoro
                        ? 'Structured focus and break sessions'
                        : 'Set your own uninterrupted timing',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.032),
                      color: secondaryTextGrey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  _buildModeToggle(),
                  SizedBox(height: screenHeight * 0.02),

                  _buildRikazConnect(),

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

                  SizedBox(height: screenHeight * 0.02),
                  
                  _buildSoundSelection(),
                  
                  SizedBox(height: screenHeight * 0.015),
                ],
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryBackground,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: proportionalHorizontalPadding,
                  right: proportionalHorizontalPadding,
                  top: screenHeight * 0.015,
                  bottom: screenHeight * 0.025,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRikazToolConnected)
                      Container(
                        margin: EdgeInsets.only(bottom: screenHeight * 0.012),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.01,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentThemeColor.withOpacity(0.08),
                              lightestAccentColor.withOpacity(0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentThemeColor.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: accentThemeColor,
                              size: _adaptiveFontSize(0.04),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Expanded(
                              child: Text(
                                'Connect hardware for enhanced features',
                                style: TextStyle(
                                  fontSize: _adaptiveFontSize(0.03),
                                  color: primaryTextDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isStartButtonEnabled ? handleStartSessionPress : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dfDeepTeal,
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: dfDeepTeal.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: _adaptiveFontSize(0.055)),
                            SizedBox(width: screenWidth * 0.015),
                            Text(
                              'Start Session',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _adaptiveFontSize(0.038),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
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