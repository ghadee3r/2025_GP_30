// ============================================================================
// FILE: SetSession.dart
// PURPOSE: Session configuration page with BLE device connection
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '/services/rikaz_light_service.dart';
import '/widgets/rikaz_device_picker.dart';
import '/main.dart';

// =============================================================================
// THEME DEFINITIONS
// =============================================================================

const Color primaryThemePurple = Color(0xFF7A68FF);
const Color hpDeepBlue = Color.fromARGB(255, 24, 114, 150);
const Color primaryTextDark = Color(0xFF30304D);
const Color secondaryTextGrey = Color(0xFF8C8C99);
const Color softAccentHighlight = Color(0xFFE9E5FF);
const Color softLavender = Color(0xFFE9E5FF);
const Color softCyan = Color(0xFFE8F8FF);
const Color primaryBackground = Color(0xFFFFFFFF);
const Color cardBackground = Color(0xFFFFFFFF);

const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: const Color.fromARGB(255, 155, 141, 255).withOpacity(0.4),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];

List<BoxShadow> get cardShadow => [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 5),
        blurRadius: 10,
      ),
    ];

// Configuration presets for quick setup
const List<String> toolPresets = [
  'Select a Preset',
  'Aggressive Focus (High Sensitivity)',
  'Study Chill (Low Sensitivity)',
  'Quiet Office (Light only)',
];

enum SessionMode { pomodoro, custom }


// =============================================================================
// SET SESSION PAGE
// =============================================================================

class SetSessionPage extends StatefulWidget {
  final SessionMode? initialMode;

  const SetSessionPage({super.key, this.initialMode});

  @override
  State<SetSessionPage> createState() => _SetSessionPageState();
}

class _SetSessionPageState extends State<SetSessionPage> {
  // --- SESSION MODE STATE ---
  late SessionMode sessionMode;

  // Pomodoro configuration
  String pomodoroDuration = '25min';
  double numberOfBlocks = 4;

  // Custom session configuration
  double customDuration = 70;

  // --- CONFIGURATION STATE ---
  bool isConfigurationOpen = false; 
  bool isCameraDetectionEnabled = true; // Future sprint: camera detection
  double sensitivity = 0.5; // Future sprint: detection sensitivity
  String notificationStyle = 'Both'; // Future sprint: alert type
  String selectedPreset = toolPresets.first;

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

  // Theme colors (local references for readability)
  final Color primaryColor = primaryThemePurple;
  final Color darkText = primaryTextDark;
  final Color lightText = secondaryTextGrey;
  final Color localCardBackground = cardBackground;
  final Color localPrimaryThemePurple = primaryThemePurple;
  final Color localSecondaryTextGrey = secondaryTextGrey;
  final double radius = cardBorderRadius / 2;
  final Color blueText = hpDeepBlue;

  @override
  void initState() {
    super.initState();
    sessionMode = widget.initialMode ?? SessionMode.pomodoro;
    _applyPreset(selectedPreset);
    
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
    super.dispose();
  }

  // Adaptive font sizing for different screen sizes
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final mitigationFactor = 0.8; 
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

  // Apply configuration preset
  void _applyPreset(String preset) {
    if (preset == 'Aggressive Focus (High Sensitivity)') {
      isCameraDetectionEnabled = true;
      sensitivity = 1.0;
      notificationStyle = 'Both';
    } else if (preset == 'Study Chill (Low Sensitivity)') {
      isCameraDetectionEnabled = true;
      sensitivity = 0.0;
      notificationStyle = 'Sound';
    } else if (preset == 'Quiet Office (Light only)') {
      isCameraDetectionEnabled = true;
      sensitivity = 0.5;
      notificationStyle = 'Light';
    } else {
      isCameraDetectionEnabled = true;
      sensitivity = 0.5;
      notificationStyle = 'Both';
    }

    if (mounted && selectedPreset != preset) {
      setState(() {
        selectedPreset = preset;
      });
    }
  }

  // Handle session start button press
  void handleStartSessionPress() {
    // Warn if device was connected but is now unplugged
    if (RikazConnectionState.isConnected && !_deviceWasConnected && _hasShownDisconnectWarning) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 48),
          title: const Text('Device Unplugged'),
          content: const Text(
            'Rikaz Tools device appears to be unplugged.\n\n'
            'The session will start without hardware control. '
            'Plug in the device to enable lights.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToSession();
              },
              child: const Text('Start Anyway'),
            ),
          ],
        ),
      );
      return;
    }
    
    _navigateToSession();
  }
  
  // Navigate to session page with configuration
  void _navigateToSession() {
    final String sessionType = sessionMode == SessionMode.pomodoro ? 'pomodoro' : 'custom';
    final String durationValue = sessionMode == SessionMode.pomodoro ? pomodoroDuration : customDuration.toInt().toString();
    final String? blocks = sessionMode == SessionMode.pomodoro ? numberOfBlocks.toInt().toString() : null;

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
        _hasShownDisconnectWarning = false;
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
      builder: (context) => AlertDialog(
        icon: Icon(Icons.link_off, color: Colors.red.shade700, size: 48),
        title: const Text('Rikaz Tools Disconnected'),
        content: const Text(
          'The Bluetooth connection to your Rikaz device was lost (unplugged or out of range).\n\n'
          'Please ensure the device is powered on and try reconnecting.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleRikazConnect(); 
            },
            child: const Text('Reconnect Now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Rikaz Tools?'),
        content: const Text(
          'This will disable hardware control (lights) for your sessions.\n\n'
          'You can reconnect anytime.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
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
          const SnackBar(
            content: Text('Rikaz Tools disconnected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      debugPrint('🔌 Rikaz Tools: Disconnected by user');
    }
  }

  // =============================================================================
  // UI COMPONENTS
  // =============================================================================

  // Disconnect button (power icon)
  Widget _buildDisconnectButton({required double screenWidth, required double screenHeight}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleRikazDisconnect,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(screenHeight * 0.01),
            child: Icon(Icons.power_settings_new, 
                color: Colors.red.shade700, 
                size: screenWidth * 0.055
            ),
          ),
        ),
      ),
    );
  }

  // Rikaz BLE connection section
  Widget _buildRikazConnect() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusColor = isRikazToolConnected ? Colors.green.shade600 : primaryColor;

    Widget content;

    // Show success confirmation after connection
    if (isRikazToolConnected && _showRikazConfirmation) {
      content = Column(
        key: const ValueKey('RikazConfirmation'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: screenWidth * 0.08),
                    SizedBox(height: screenHeight * 0.01),
                    Text('Connection Successful! 🎉',
                        style: TextStyle(
                            fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: statusColor)),
                    SizedBox(height: screenHeight * 0.008),
                    Text('You can now monitor your focus and apply custom configurations to your sessions.',
                        style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)),
                  ],
                ),
              ),
              _buildDisconnectButton(screenWidth: screenWidth, screenHeight: screenHeight),
            ],
          ),
        ],
      );
    } 
    // Show active connection status
    else if (isRikazToolConnected) {
      content = Column(
        key: const ValueKey('RikazConnectedWithDisconnect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: screenWidth * 0.06),
                        SizedBox(width: screenWidth * 0.02),
                        Text('Rikaz Tools Active',
                            style: TextStyle(
                                fontSize: _adaptiveFontSize(0.045), 
                                fontWeight: FontWeight.bold, 
                                color: statusColor)),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text('Hardware connected. Configuration available below.',
                        style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)),
                  ],
                ),
              ),
              _buildDisconnectButton(screenWidth: screenWidth, screenHeight: screenHeight),
            ],
          ),
        ],
      );
    } 
    // Show connection slider
    else {
      content = Column(
        key: const ValueKey('RikazDisconnected'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect Rikaz Tools',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)),
          SizedBox(height: screenHeight * 0.008),
          Text(
              'Slide to scan and connect via Bluetooth.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)),
          SizedBox(height: screenHeight * 0.02),
          SlideAction(
            key: _slideKey,
            text: isLoading ? "Scanning..." : "Slide to Scan",
            textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.038),
                fontWeight: FontWeight.w600,
                color: Colors.white),
            innerColor: localCardBackground,
            outerColor: primaryColor.withOpacity(0.9),
            sliderButtonIcon:
            Icon(Icons.bluetooth_searching, color: darkText, size: screenWidth * 0.05),
            height: screenHeight * 0.055,
            borderRadius: cardBorderRadius,
            onSubmit: isLoading ? null : () async {
              await _handleRikazConnect();
              return null;
            },
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey(isRikazToolConnected.toString() + _showRikazConfirmation.toString()), 
        padding: EdgeInsets.all(screenWidth * 0.04),
        margin: EdgeInsets.only(bottom: screenHeight * 0.035), 
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          boxShadow: subtleShadow,
          border: Border.all(color: Colors.grey.shade100, width: 1.0),
        ),
        child: content,
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
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: screenHeight * 0.018),
        padding: EdgeInsets.all(screenWidth * 0.045),
        decoration: BoxDecoration(
          color: isSelected ? softLavender.withOpacity(0.8) : cardBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: 1.5),
          boxShadow: cardShadow,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? primaryColor : lightText.withOpacity(0.7),
              size: screenWidth * 0.06,
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.w600, color: darkText)),
            ),
            Text(breakText, style: TextStyle(
                fontSize: _adaptiveFontSize(0.035), color: lightText)),
          ],
        ),
      ),
    );
  }

  // Pomodoro blocks slider (1-8 blocks)
  Widget _pomodoroBlocksSlider() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Number of Blocks',
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)),
        SizedBox(height: screenHeight * 0.02),
        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.025),
          decoration: BoxDecoration(
            color: softCyan.withOpacity(0.5),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: cardShadow,
          ),
          child: Column(
            children: [
              Center(
                child: Text(
                  numberOfBlocks.toInt().toString(),
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.12), fontWeight: FontWeight.bold, color: blueText),
                ),
              ),
              Slider(
                value: numberOfBlocks,
                min: 1,
                max: 8,
                divisions: 7,
                label: '${numberOfBlocks.toInt()}',
                onChanged: (v) => setState(() => numberOfBlocks = v),
                activeColor: blueText,
                inactiveColor: softAccentHighlight,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.005),
                child: Text(
                  'One block = one focus session followed by its break.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.035), color: lightText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Custom duration slider (25-120 minutes)
  Widget _customDurationSlider() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Duration',
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)),
        SizedBox(height: screenHeight * 0.02),
        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.025),
          decoration: BoxDecoration(
            color: softCyan.withOpacity(0.5),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: cardShadow,
          ),
          child: Column(
            children: [
              Center(
                child: Text(
                  '${customDuration.toInt()}:00',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.12), fontWeight: FontWeight.bold, color: hpDeepBlue),
                ),
              ),
              Text('No Breaks',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.04), color: lightText)),
              Slider(
                value: customDuration,
                min: 25,
                max: 120,
                divisions: (120 - 25),
                label: '${customDuration.toInt()} min',
                onChanged: (v) => setState(() => customDuration = v),
                activeColor: hpDeepBlue,
                inactiveColor: softAccentHighlight,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('25 Minutes', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: lightText)),
                    Text('120 Minutes', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: lightText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Configuration menu (sensitivity, notification style) - Future sprint features
  Widget _configurationMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isConfigurationDisabled = !isRikazToolConnected;
    final disabledColor = Colors.grey.shade200;
    final disabledBorderColor = Colors.grey.shade300;
    final disabledTextColor = Colors.grey.shade500;
    final activeMenuColor = cardBackground;
    final activeMenuBorderColor = Colors.grey.shade200;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: isConfigurationDisabled ? disabledColor : activeMenuColor,
        border: Border.all(color: isConfigurationDisabled ? disabledBorderColor : activeMenuBorderColor),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      ),
      child: IgnorePointer(
        ignoring: isConfigurationDisabled,
        child: Column(
          children: [
            if (isConfigurationDisabled)
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.015),
                child: Text(
                  'Connection Required to edit settings.',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.038),
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            
            // Sensitivity slider (Future sprint)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sensitivity', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)),
                Row(
                  children: [
                    Text('Low', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: isConfigurationDisabled ? disabledTextColor : lightText)),
                    Expanded(
                      child: Slider(
                        value: sensitivity,
                        min: 0,
                        max: 1,
                        divisions: 2,
                        label: sensitivity == 0 ? 'Low' : sensitivity == 0.5 ? 'Medium' : 'High',
                        onChanged: isConfigurationDisabled ? null : (v) {
                          setState(() {
                            sensitivity = v;
                            selectedPreset = toolPresets.first;
                          });
                        },
                        activeColor: primaryColor.withOpacity(isConfigurationDisabled ? 0.4 : 1.0),
                        inactiveColor: softAccentHighlight,
                      ),
                    ),
                    Text('High', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: isConfigurationDisabled ? disabledTextColor : lightText)),
                  ],
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),

            // Notification style (Future sprint)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notification Style', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)),
                SizedBox(height: screenHeight * 0.015),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Light', 'Sound', 'Both'].map((option) {
                    final isSelected = notificationStyle == option;
                    return Expanded(
                      child: GestureDetector(
                        onTap: isConfigurationDisabled ? null : () {
                          setState(() {
                            notificationStyle = option;
                            selectedPreset = toolPresets.first;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                          child: Row(
                            children: [
                              Container(
                                width: screenWidth * 0.045,
                                height: screenWidth * 0.045,
                                margin: EdgeInsets.only(right: screenWidth * 0.01),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? primaryColor : (isConfigurationDisabled ? disabledTextColor : Colors.grey)),
                                  color: isSelected ? primaryColor.withOpacity(isConfigurationDisabled ? 0.4 : 1.0) : Colors.transparent,
                                ),
                              ),
                              Text(option, style: TextStyle(color: isConfigurationDisabled ? disabledTextColor : darkText,
                                  fontSize: _adaptiveFontSize(0.035))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Session mode toggle (Pomodoro vs Custom)
  Widget _buildModeToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenHeight * 0.005),
      decoration: BoxDecoration(
        color: softAccentHighlight.withOpacity(0.5),
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

  // Mode toggle button
  Widget _toggleButton(SessionMode mode, String text, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = sessionMode == mode;
    final selectedColor = primaryColor;
    final unselectedColor = secondaryTextGrey;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          sessionMode = mode;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
          decoration: BoxDecoration(
            color: isSelected ? cardBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: screenWidth * 0.05, color: isSelected ? selectedColor : unselectedColor),
              SizedBox(width: screenWidth * 0.02),
              Text(
                text,
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.035),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ],
          ),
        ),
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
    final proportionalHorizontalPadding = screenWidth * 0.1;

    final bool isStartButtonEnabled = !isLoading;
    final Color startButtonColor = isStartButtonEnabled ? primaryColor : Colors.grey.shade400;

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
              fontSize: _adaptiveFontSize(0.05), fontWeight: FontWeight.bold, color: primaryTextDark),
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
                top: 0,
                bottom: screenHeight * 0.18, 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.015),
                  
                  // Page title
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Pomodoro Session' : 'Custom Session',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.07), fontWeight: FontWeight.bold, color: hpDeepBlue)),
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Configure your structured focus routine' : 'Set your own uninterrupted timing',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.04), color: secondaryTextGrey)),
                  SizedBox(height: screenHeight * 0.035),

                  // Session mode toggle
                  _buildModeToggle(),
                  SizedBox(height: screenHeight * 0.035),

                  // Rikaz BLE connection section
                  _buildRikazConnect(),

                  // Session configuration (Pomodoro or Custom)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: (sessionMode == SessionMode.pomodoro)
                        ? Column(
                      key: const ValueKey(SessionMode.pomodoro),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duration Options',
                            style: TextStyle(
                                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)),
                        SizedBox(height: screenHeight * 0.02),
                        _pomodoroDurationOption('25min', '+ 5 min break'),
                        _pomodoroDurationOption('50min', '+ 10 min break'),
                        SizedBox(height: screenHeight * 0.035),
                        _pomodoroBlocksSlider(),
                      ],
                    )
                        : Column(
                      key: const ValueKey(SessionMode.custom),
                      children: [_customDurationSlider()],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.035),

                  // Configuration menu toggle
                  if (!_showRikazConfirmation)
                    GestureDetector(
                      onTap: isRikazToolConnected ? () => setState(() => isConfigurationOpen = !isConfigurationOpen) : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
                        decoration: BoxDecoration(
                          color: isRikazToolConnected ? cardBackground : Colors.grey.shade200, 
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(color: isRikazToolConnected ? primaryColor.withOpacity(0.5) : Colors.grey.shade400),
                          boxShadow: cardShadow, 
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rikaz Tools Configuration',
                                style: TextStyle(
                                    color: isRikazToolConnected ? darkText : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: _adaptiveFontSize(0.04))),
                            Icon(isConfigurationOpen && isRikazToolConnected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: isRikazToolConnected ? primaryColor : Colors.grey.shade600,
                                size: screenWidth * 0.06),
                          ],
                        ),
                      ),
                    ),

                  // Expandable configuration menu
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SizeTransition(
                        sizeFactor: animation,
                        child: child,
                      );
                    },
                    child: isConfigurationOpen 
                        ? Padding(
                      key: ValueKey('ConfigOpen_$isRikazToolConnected'), 
                      padding: EdgeInsets.only(top: screenHeight * 0.015),
                      child: _configurationMenu(),
                    )
                        : const SizedBox.shrink(key: ValueKey('ConfigClosed')),
                  ),
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
                  color: primaryBackground.withOpacity(0.95),
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
                    // Warning when hardware is offline
                    if (!isRikazToolConnected)
                      Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                        child: Center(
                          child: Text(
                            'Rikaz tools offline. Session tracking will be limited.',
                            style: TextStyle(
                              fontSize: _adaptiveFontSize(0.03),
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      
                    // Start session button
                    ElevatedButton(
                      onPressed: isStartButtonEnabled ? handleStartSessionPress : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: startButtonColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius)),
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.022),
                        elevation: 8,
                        shadowColor: startButtonColor.withOpacity(0.6),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: isStartButtonEnabled
                            ? Text(
                                'Start Session',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold),
                              )
                            : SizedBox(
                                width: screenWidth * 0.055, 
                                height: screenWidth * 0.055, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
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