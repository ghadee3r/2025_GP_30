// ============================================================================
// FILE: SetSession.dart (COMPLETE - Fixed Version)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '/services/wled_service.dart';

// Import the global connection state from main.dart
// If you get import errors, use this instead:
// import '../../main.dart' show WledConnectionState;

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

const List<String> toolPresets = [
      'Select a Preset',
      'Aggressive Focus (High Sensitivity)',
      'Study Chill (Low Sensitivity)',
      'Quiet Office (Light only)',
    ];

enum SessionMode { pomodoro, custom }

// ADDED: Import this class from main.dart or define it here if needed
class WledConnectionState {
  static bool _isConnected = false;
  
  static bool get isConnected => _isConnected;
  
  static void setConnected(bool value) {
    _isConnected = value;
    debugPrint('🔌 WLED Global State: ${value ? "CONNECTED" : "DISCONNECTED"}');
  }
  
  static void reset() {
    _isConnected = false;
    debugPrint('🔌 WLED Global State: RESET');
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

class _SetSessionPageState extends State<SetSessionPage> {
  // --- STATE VARIABLES ---
  late SessionMode sessionMode;

  // Pomodoro State
  String pomodoroDuration = '25min';
  double numberOfBlocks = 4;

  // Custom State
  double customDuration = 70;

  // Configuration State
  bool isConfigurationOpen = false; 
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';
  String selectedPreset = toolPresets.first;

  // RIKAZ CONNECT STATE - MODIFIED to use global state
  bool get isRikazToolConnected => WledConnectionState.isConnected;
  bool isLoading = false;
  bool _showRikazConfirmation = false;

  // WLED SERVICE
  final WledService _wledService = WledService();

  // ADDED: Slider key to reset animation
  final GlobalKey<SlideActionState> _slideKey = GlobalKey<SlideActionState>();

  // Local theme variables
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
    
    // ADDED: If already connected, show the configuration immediately
    if (WledConnectionState.isConnected) {
      debugPrint('🔌 Restored connection state from previous session');
      isConfigurationOpen = true;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final mitigationFactor = 0.8; 
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

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

  void handleStartSessionPress() {
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
        'wledConnected': WledConnectionState.isConnected, // FIXED: Use global state
      },
    );
  }

  // MODIFIED: Fixed animation controller error and uses global state
  Future<void> _handleRikazConnect() async {
    if (WledConnectionState.isConnected) return;

    setState(() => isLoading = true);

    // Test WLED connection
    final bool wledConnected = await _wledService.testConnection();
    
    if (!mounted) return;
    
    if (wledConnected) {
      // FIXED: Set global connection state BEFORE showing confirmation
      WledConnectionState.setConnected(true);
      
      setState(() {
        isLoading = false;
        _showRikazConfirmation = true;
      });
      
      print('✅ Rikaz Tools: WLED connected successfully');
      
      // Wait for confirmation display
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
      
      // FIXED: Reset slide animation BEFORE showing error dialog
      try {
        _slideKey.currentState?.reset();
      } catch (e) {
        debugPrint('Slider reset error (safe to ignore): $e');
      }
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Failed'),
            content: const Text(
              'Could not connect to WLED device.\n\n'
              'Please check:\n'
              '• WLED device is powered on\n'
              '• Device IP matches in code\n'
              '• Both devices are on same network'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildRikazConnect() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusColor = isRikazToolConnected ? Colors.green.shade600 : primaryColor;

    Widget content;

    if (isRikazToolConnected && _showRikazConfirmation) {
      content = Column(
        key: const ValueKey('RikazConfirmation'),
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
      );
    } else if (isRikazToolConnected) {
      content = Column(
        key: const ValueKey('RikazConnectedHidden'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rikaz Tools Active',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: statusColor)),
          SizedBox(height: screenHeight * 0.01),
          Text('Tool connected. Configuration is available below.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)),
        ],
      );
    } else {
      content = Column(
        key: const ValueKey('RikazDisconnected'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect Rikaz Tools',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)),
          SizedBox(height: screenHeight * 0.008),
          Text(
              'Slide to connect the Rikaz focus tools and unlock settings.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)),
          SizedBox(height: screenHeight * 0.02),
          SlideAction(
            key: _slideKey, // ADDED: Key for resetting animation
            text: isLoading ? "Connecting..." : "Slide to Connect",
            textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.038),
                fontWeight: FontWeight.w600,
                color: Colors.white),
            innerColor: localCardBackground,
            outerColor: primaryColor.withOpacity(0.9),
            sliderButtonIcon:
            Icon(Icons.wifi, color: darkText, size: screenWidth * 0.05),
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
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rikaz Tools Preset', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.035), color: isConfigurationDisabled ? disabledTextColor : darkText, fontWeight: FontWeight.bold)),
                SizedBox(height: screenHeight * 0.01),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: softAccentHighlight.withOpacity(isConfigurationDisabled ? 0.2 : 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withOpacity(isConfigurationDisabled ? 0.1 : 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPreset,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: isConfigurationDisabled ? disabledTextColor : primaryColor),
                      style: TextStyle(color: isConfigurationDisabled ? disabledTextColor : darkText,
                          fontSize: _adaptiveFontSize(0.04)),
                      dropdownColor: cardBackground,
                      onChanged: isConfigurationDisabled ? null : (String? newValue) {
                        if (newValue != null) {
                          _applyPreset(newValue);
                        }
                      },
                      items: toolPresets.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(color: darkText, fontSize: _adaptiveFontSize(0.04))),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.025),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Camera Detection', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)),
                Switch(
                  value: isCameraDetectionEnabled,
                  onChanged: isConfigurationDisabled ? null : (v) {
                    setState(() {
                      isCameraDetectionEnabled = v;
                      selectedPreset = toolPresets.first;
                    });
                  },
                  activeThumbColor: primaryColor.withOpacity(isConfigurationDisabled ? 0.4 : 1.0),
                  inactiveTrackColor: Colors.grey.shade300,
                  inactiveThumbColor: isConfigurationDisabled ? disabledTextColor : null,
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Triggers', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)),
                Row(
                  children: List.generate(
                    3,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.015),
                      width: screenWidth * 0.05,
                      height: screenWidth * 0.05,
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor.withOpacity(isConfigurationDisabled ? 0.2 : 0.8), width: 2),
                        borderRadius: BorderRadius.circular(5),
                        color: softAccentHighlight.withOpacity(isConfigurationDisabled ? 0.1 : 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
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
                  
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Pomodoro Session' : 'Custom Session',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.07), fontWeight: FontWeight.bold, color: hpDeepBlue)),
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Configure your structured focus routine' : 'Set your own uninterrupted timing',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.04), color: secondaryTextGrey)),
                  SizedBox(height: screenHeight * 0.035),

                  _buildModeToggle(),
                  SizedBox(height: screenHeight * 0.035),

                  _buildRikazConnect(),

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