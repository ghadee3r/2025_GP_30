import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

// =============================================================================
// RECREATED THEME DEFINITIONS FOR SCOPE (Centralized Constants)
// =============================================================================

// Base Colors
const Color primaryThemePurple = Color(0xFF7A68FF); // Main action color
const Color hpDeepBlue = Color.fromARGB(255, 24, 114, 150); // Header/Key Text (Target Blue)
const Color primaryTextDark = Color(0xFF30304D);
const Color secondaryTextGrey = Color(0xFF8C8C99);
const Color softAccentHighlight = Color(0xFFE9E5FF); // Lightest purple for selections/backgrounds
const Color softLavender = Color(0xFFE9E5FF); // Used for UI element backgrounds
const Color softCyan = Color(0xFFE8F8FF);
const Color primaryBackground = Color(0xFFFFFFFF);
const Color cardBackground = Color(0xFFFFFFFF);

const double cardBorderRadius = 24.0;

// Subtle shadow for the floating effect (Purple-tinted) - Original subtleShadow kept for Rikaz Connect Card
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: const Color.fromARGB(255, 155, 141, 255).withOpacity(0.4),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];

// Shadow for unselected/inner cards
List<BoxShadow> get cardShadow => [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 5),
        blurRadius: 10,
      ),
    ];

// Define Presets for the Dropdown
const List<String> toolPresets = [
      'Select a Preset',
      'Aggressive Focus (High Sensitivity)',
      'Study Chill (Low Sensitivity)',
      'Quiet Office (Light only)',
    ];

// Enum to manage the session configuration mode (MUST BE DEFINED HERE OR IMPORTED)
enum SessionMode { pomodoro, custom }

// =============================================================================
// FOCUS CONFIGURATION PAGE (SetSessionPage) - MODIFIED INITIALIZATION
// =============================================================================

class SetSessionPage extends StatefulWidget {
  // MODIFIED: The constructor now expects the initialMode to be passed.
  // We make it required for clarity, although null handling is in initState.
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

  // Configuration State (Shared)
  bool isConfigurationOpen = false; 
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';
  String selectedPreset = toolPresets.first;

  // RIKAZ CONNECT STATE
  bool isRikazToolConnected = false;
  bool isLoading = false;
  bool _showRikazConfirmation = false;

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
    // MODIFIED: Use the value passed in the constructor (which should come from navigation arguments).
    sessionMode = widget.initialMode ?? SessionMode.pomodoro;
    _applyPreset(selectedPreset);
  }

  @override
  void dispose() {
    super.dispose();
  }

    // NEW HELPER: Adaptive Font Size function
    // Adjusts the proportional font size based on the system's text scale factor to prevent overflow
    double _adaptiveFontSize(double baseScreenWidthMultiplier) {
        final screenWidth = MediaQuery.of(context).size.width;
        final baseSize = screenWidth * baseScreenWidthMultiplier;
        final textScaleFactor = MediaQuery.of(context).textScaleFactor;
        
        // Mitigation factor to prevent excessive scaling on devices with large system fonts
        final mitigationFactor = 0.8; 
        
        // Size = BaseSize / (1.0 + (ScaleFactor - 1.0) * MitigationFactor)
        return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
    }

  // --- LOGIC (Functionality Unchanged) ---
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
      },
    );
  }

  Future<void> _handleRikazConnect() async {
    if (isRikazToolConnected) return;

    setState(() => isLoading = true);
    // FIX: Increased delay slightly for better UX, but protected by mounted check
    await Future.delayed(const Duration(milliseconds: 1500)); 

    if (!mounted) return; // FIX: Protects setState after await
    setState(() {
      isRikazToolConnected = true;
      isLoading = false;
      _showRikazConfirmation = true;
    });

    // Delay for confirmation visibility
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) { // FIX: Protects final setState
      setState(() {
        _showRikazConfirmation = false;
        isConfigurationOpen = true; 
      });
    }
  }


  // --- FLEXIBLE UI Component Builders ---

  Widget _buildRikazConnect() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusColor = isRikazToolConnected ? Colors.green.shade600 : primaryColor;

    Widget content;

    if (isRikazToolConnected && _showRikazConfirmation) {
      // 1. Confirmation State
      content = Column(
        key: const ValueKey('RikazConfirmation'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: screenWidth * 0.08),
          SizedBox(height: screenHeight * 0.01),
          Text('Connection Successful! 🎉',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: statusColor)), // MODIFIED
          SizedBox(height: screenHeight * 0.008),
          Text('You can now monitor your focus and apply custom configurations to your sessions.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)), // MODIFIED
        ],
      );
    } else if (isRikazToolConnected) {
      // 2. Connected State (Simple message when not confirming)
      content = Column(
        key: const ValueKey('RikazConnectedHidden'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rikaz Tools Active',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: statusColor)), // MODIFIED
          SizedBox(height: screenHeight * 0.01),
          Text('Tool connected. Configuration is available below.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)), // MODIFIED
        ],
      );
    } else {
      // 3. Disconnected State (The Slide to Connect Action)
      content = Column(
        key: const ValueKey('RikazDisconnected'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect Rikaz Tools',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)), // MODIFIED
          SizedBox(height: screenHeight * 0.008),
          Text(
              'Slide to connect the Rikaz focus tools and unlock settings.',
              style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: localSecondaryTextGrey)), // MODIFIED
          SizedBox(height: screenHeight * 0.02),
          SlideAction(
            text: isLoading ? "Connecting..." : "Slide to Connect",
            textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.038), // MODIFIED
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
          boxShadow: cardShadow, // Subtle shadow is kept for options but removed the heavy purple tint one
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
                      fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.w600, color: darkText)), // MODIFIED
            ),
            Text(breakText, style: TextStyle(
                fontSize: _adaptiveFontSize(0.035), color: lightText)), // MODIFIED
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
                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)), // MODIFIED
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
                      fontSize: _adaptiveFontSize(0.12), fontWeight: FontWeight.bold, color: blueText), // MODIFIED
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
                      fontSize: _adaptiveFontSize(0.035), color: lightText), // MODIFIED
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
                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)), // MODIFIED
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
                      fontSize: _adaptiveFontSize(0.12), fontWeight: FontWeight.bold, color: hpDeepBlue), // MODIFIED
                ),
              ),
              Text('No Breaks',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.04), color: lightText)), // MODIFIED
              Slider(
                value: customDuration,
                min: 25,
                max: 120,
                divisions: (120 - 25), // 95 divisions
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
                        fontSize: _adaptiveFontSize(0.03), color: lightText)), // MODIFIED
                    Text('120 Minutes', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: lightText)), // MODIFIED
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Themed Configuration Menu Widget (MODIFIED FOR DISABLED STATE)
  Widget _configurationMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Disabled state styling
    final isConfigurationDisabled = !isRikazToolConnected;
    final disabledColor = Colors.grey.shade200;
    final disabledBorderColor = Colors.grey.shade300;
    final disabledTextColor = Colors.grey.shade500;
    final activeMenuColor = cardBackground;
    final activeMenuBorderColor = Colors.grey.shade200;

    return Container(
      // FLEXIBLE PADDING
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: isConfigurationDisabled ? disabledColor : activeMenuColor,
        border: Border.all(color: isConfigurationDisabled ? disabledBorderColor : activeMenuBorderColor),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      ),
      // Use IgnorePointer when disabled to prevent accidental interaction
      child: IgnorePointer(
        ignoring: isConfigurationDisabled,
        child: Column(
          children: [
            // This message is only shown *inside* the menu when the menu is open, and is disabled.
            if (isConfigurationDisabled)
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.015),
                child: Text(
                  'Connection Required to edit settings.',
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.038), // MODIFIED
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            
            // Rikaz Tool Preset Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rikaz Tools Preset', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.035), color: isConfigurationDisabled ? disabledTextColor : darkText, fontWeight: FontWeight.bold)), // MODIFIED
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
                          fontSize: _adaptiveFontSize(0.04)), // MODIFIED
                      dropdownColor: cardBackground,
                      onChanged: isConfigurationDisabled ? null : (String? newValue) {
                        if (newValue != null) {
                          _applyPreset(newValue);
                        }
                      },
                      items: toolPresets.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(color: darkText, fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.025),

            // Camera Switch (Themed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Camera Detection', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)), // MODIFIED
                Switch(
                  value: isCameraDetectionEnabled,
                  onChanged: isConfigurationDisabled ? null : (v) {
                    setState(() {
                      isCameraDetectionEnabled = v;
                      selectedPreset = toolPresets.first;
                    });
                  },
                  activeColor: primaryColor.withOpacity(isConfigurationDisabled ? 0.4 : 1.0),
                  inactiveTrackColor: Colors.grey.shade300,
                  inactiveThumbColor: isConfigurationDisabled ? disabledTextColor : null,
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Triggers (Themed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Triggers', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)), // MODIFIED
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
            
            // Sensitivity Slider (Themed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sensitivity', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)), // MODIFIED
                Row(
                  children: [
                    Text('Low', style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03), color: isConfigurationDisabled ? disabledTextColor : lightText)), // MODIFIED
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
                        fontSize: _adaptiveFontSize(0.03), color: isConfigurationDisabled ? disabledTextColor : lightText)), // MODIFIED
                  ],
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),

            // Notification Style Radios (Themed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notification Style', style: TextStyle(
                    fontSize: _adaptiveFontSize(0.04), color: isConfigurationDisabled ? disabledTextColor : darkText)), // MODIFIED
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
                                  fontSize: _adaptiveFontSize(0.035))), // MODIFIED
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

  // Mode Toggle and Helper Buttons (Unchanged)
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
                  fontSize: _adaptiveFontSize(0.035), // MODIFIED
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

    // Determine Start Button style
    final bool isStartButtonEnabled = !isLoading;
    final Color startButtonColor = isStartButtonEnabled ? primaryColor : Colors.grey.shade400;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextDark),
          onPressed: () => Navigator.of(context).pop(), // CORRECT pop command
        ),
        title: Text(
          'Set Session',
          style: TextStyle(
              fontSize: _adaptiveFontSize(0.05), fontWeight: FontWeight.bold, color: primaryTextDark), // MODIFIED
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
                // Adjust bottom padding to accommodate the fixed bottom bar
                bottom: screenHeight * 0.18, 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.015),
                  
                  // Dynamic Header based on selected mode
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Pomodoro Session' : 'Custom Session',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.07), fontWeight: FontWeight.bold, color: hpDeepBlue)), // MODIFIED
                  Text(
                    sessionMode == SessionMode.pomodoro ? 'Configure your structured focus routine' : 'Set your own uninterrupted timing',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.04), color: secondaryTextGrey)), // MODIFIED
                  SizedBox(height: screenHeight * 0.035),

                  // MODE TOGGLE BUTTONS
                  _buildModeToggle(),
                  SizedBox(height: screenHeight * 0.035),

                  // === RIKAZ CONNECT COMPONENT (Placed after mode toggle, before duration) ===
                  _buildRikazConnect(),

                  // CONDITIONAL DURATION SECTION
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
                                fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: darkText)), // MODIFIED
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

                  // === CONFIGURATION TOGGLE/MENU HEADER ===
                  if (!_showRikazConfirmation)
                    GestureDetector(
                      // Toggle button is interactive only if connected
                      onTap: isRikazToolConnected ? () => setState(() => isConfigurationOpen = !isConfigurationOpen) : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
                        decoration: BoxDecoration(
                          // If connected, use cardBackground (white). If not connected, use Colors.grey.shade200.
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
                                    fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                            Icon(isConfigurationOpen && isRikazToolConnected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: isRikazToolConnected ? primaryColor : Colors.grey.shade600,
                                size: screenWidth * 0.06),
                          ],
                        ),
                      ),
                    ),

                  // Configuration Content
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
                      key: ValueKey('ConfigOpen_${isRikazToolConnected}'), 
                      padding: EdgeInsets.only(top: screenHeight * 0.015),
                      child: _configurationMenu(), // Renders grayed-out content if disconnected
                    )
                        : const SizedBox.shrink(key: ValueKey('ConfigClosed')),
                  ),
                ],
              ),
            ),

            // FIXED BOTTOM SECTION FOR START BUTTON (FADED BACKGROUND)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                // ADDED: Faded background to separate the fixed button from content
                decoration: BoxDecoration(
                  color: primaryBackground.withOpacity(0.95), // Slightly less transparent for better fade
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
                  bottom: screenHeight * 0.03, // Adjusted to position button at bottom
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Note for Start Session button
                    if (!isRikazToolConnected)
                      Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                        child: Center(
                          child: Text(
                            'Rikaz tools offline. Session tracking will be limited.',
                            style: TextStyle(
                              fontSize: _adaptiveFontSize(0.03), // MODIFIED
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      
                    // Start button
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
                      child: SizedBox( // Enforce max width for button text area
                        width: double.infinity,
                        child: Center(
                          child: isStartButtonEnabled
                            ? Text(
                                'Start Session',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold), // MODIFIED
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