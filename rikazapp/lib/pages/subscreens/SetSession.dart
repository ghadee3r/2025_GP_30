import 'package:flutter/material.dart';

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
const double globalHorizontalPadding = 42.5; 

// Subtle shadow for the floating effect (Purple-tinted) - Used for Pomodoro options
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

// Enum to manage the session configuration mode
enum SessionMode { pomodoro, custom }

// =============================================================================
// MERGED FOCUS CONFIGURATION PAGE (SetSessionPage)
// =============================================================================

class SetSessionPage extends StatefulWidget {
    // MODIFIED: Accepts an optional initial mode from the previous page
    final SessionMode? initialMode;

    const SetSessionPage({super.key, this.initialMode});

    @override
    State<SetSessionPage> createState() => _SetSessionPageState();
}

class _SetSessionPageState extends State<SetSessionPage> {
    // Session State
    // MODIFIED: Initialize state from widget.initialMode, defaulting to pomodoro
    late SessionMode sessionMode;

    // Pomodoro State
    String pomodoroDuration = '25min';
    double numberOfBlocks = 4;

    // Custom State
    double customDuration = 70; // Default between 25 and 120

    // Configuration State (Shared)
    bool isConfigurationOpen = false;
    bool isCameraDetectionEnabled = true;
    double sensitivity = 0.5;
    String notificationStyle = 'Both';
    String selectedPreset = toolPresets.first;
    bool isLoading = false;


    // Local theme variables
    final Color primaryColor = primaryThemePurple;
    final Color darkText = primaryTextDark;
    final Color lightText = secondaryTextGrey;
    final double radius = cardBorderRadius / 2;
    final Color blueText = hpDeepBlue;


    @override
    void initState() {
        super.initState();
        // INITIALIZATION CHANGE: Set sessionMode based on the passed argument
        sessionMode = widget.initialMode ?? SessionMode.pomodoro;

        _applyPreset(selectedPreset);
    }

    // Applies settings from the tool preset dropdown
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
            setState(() { selectedPreset = preset; });
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
    
    // --- UI Component Builders ---

    // Themed Duration Option Widget (Used only in Pomodoro Mode)
    Widget _pomodoroDurationOption(String label, String breakText) {
        final isSelected = pomodoroDuration == label;
        return GestureDetector(
            onTap: () => setState(() => pomodoroDuration = label),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: isSelected ? softLavender.withOpacity(0.8) : cardBackground,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: 1.5),
                    boxShadow: isSelected ? subtleShadow : cardShadow,
                ),
                child: Row(
                    children: [
                        Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? primaryColor : lightText.withOpacity(0.7),
                            size: 24,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                            child: Text(label,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        Text(breakText, style: TextStyle(fontSize: 14, color: lightText)),
                    ],
                ),
            ),
        );
    }
    
    // Number of Blocks Slider (Used only in Pomodoro Mode)
    Widget _pomodoroBlocksSlider() {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('Number of Blocks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
                const SizedBox(height: 15),
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
                                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: blueText),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                child: Text(
                                    'One block = one focus session followed by its break.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: lightText),
                                ),
                            ),
                        ],
                    ),
                ),
            ],
        );
    }

    // Custom Duration Slider (Used only in Custom Mode)
    Widget _customDurationSlider() {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('Session Duration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
                const SizedBox(height: 15),
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
                                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: hpDeepBlue),
                                ),
                            ),
                            Text('No Breaks',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: lightText)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text('25 Minutes', style: TextStyle(fontSize: 12, color: lightText)),
                                        Text('120 Minutes', style: TextStyle(fontSize: 12, color: lightText)),
                                    ],
                                ),
                            ),
                        ],
                    ),
                ),
            ],
        );
    }


    // Themed Configuration Menu Widget (Shared)
    Widget _configurationMenu() {
        return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: cardBackground,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(radius),
                boxShadow: cardShadow,
            ),
            child: Column(
                children: [
                    // Rikaz Tool Preset Dropdown
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('Rikaz Tools Preset', style: TextStyle(fontSize: 14, color: darkText, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                    color: softAccentHighlight.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                                ),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        value: selectedPreset,
                                        isExpanded: true,
                                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                                        style: TextStyle(color: darkText, fontSize: 16),
                                        dropdownColor: cardBackground,
                                        onChanged: (String? newValue) {
                                            if (newValue != null) {
                                                _applyPreset(newValue);
                                            }
                                        },
                                        items: toolPresets.map<DropdownMenuItem<String>>((String value) {
                                            return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value, style: TextStyle(color: darkText)),
                                            );
                                        }).toList(),
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 20),

                    // Camera Switch (Themed)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text('Camera Detection', style: TextStyle(fontSize: 16, color: darkText)),
                            Switch(
                                value: isCameraDetectionEnabled,
                                onChanged: (v) {
                                    setState(() {
                                        isCameraDetectionEnabled = v;
                                        selectedPreset = toolPresets.first;
                                    });
                                },
                                activeColor: primaryColor,
                                inactiveTrackColor: Colors.grey.shade300,
                            ),
                        ],
                    ),
                    const SizedBox(height: 15),

                    // Triggers (Themed)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text('Triggers', style: TextStyle(fontSize: 16, color: darkText)),
                            Row(
                                children: List.generate(
                                    3,
                                    (index) => Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                            border: Border.all(color: primaryColor.withOpacity(0.8), width: 2),
                                            borderRadius: BorderRadius.circular(5),
                                            color: softAccentHighlight.withOpacity(0.5),
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 15),

                    // Sensitivity Slider (Themed)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('Sensitivity', style: TextStyle(fontSize: 16, color: darkText)),
                            Row(
                                children: [
                                    Text('Low', style: TextStyle(fontSize: 12, color: lightText)),
                                    Expanded(
                                        child: Slider(
                                            value: sensitivity,
                                            min: 0,
                                            max: 1,
                                            divisions: 2,
                                            label: sensitivity == 0 ? 'Low' : sensitivity == 0.5 ? 'Medium' : 'High',
                                            onChanged: (v) {
                                                setState(() {
                                                    sensitivity = v;
                                                    selectedPreset = toolPresets.first;
                                                });
                                            },
                                            activeColor: primaryColor,
                                            inactiveColor: softAccentHighlight,
                                        ),
                                    ),
                                    Text('High', style: TextStyle(fontSize: 12, color: lightText)),
                                ],
                            ),
                        ],
                    ),
                    const SizedBox(height: 15),

                    // Notification Style Radios (Themed)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('Notification Style', style: TextStyle(fontSize: 16, color: darkText)),
                            const SizedBox(height: 10),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: ['Light', 'Sound', 'Both'].map((option) {
                                    final isSelected = notificationStyle == option;
                                    return GestureDetector(
                                        onTap: () {
                                            setState(() {
                                                notificationStyle = option;
                                                selectedPreset = toolPresets.first;
                                            });
                                        },
                                        child: Row(
                                            children: [
                                                Container(
                                                    width: 20,
                                                    height: 20,
                                                    margin: const EdgeInsets.only(right: 5),
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: isSelected ? primaryColor : Colors.grey),
                                                        color: isSelected ? primaryColor : Colors.transparent,
                                                    ),
                                                ),
                                                Text(option, style: TextStyle(color: darkText)),
                                            ],
                                        ),
                                    );
                                }).toList(),
                            ),
                        ],
                    ),
                ],
            ),
        );
    }


    @override
    Widget build(BuildContext context) {
        // --- NOTE: When using the initialMode from the constructor, the app bar title 
        // and session title will correctly reflect the selection from the home page.
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextDark),
                ),
                centerTitle: true,
            ),
            backgroundColor: primaryBackground,
            body: SafeArea(
                child: Stack(
                    children: [
                        SingleChildScrollView(
                            padding: EdgeInsets.only(
                                left: globalHorizontalPadding,
                                right: globalHorizontalPadding,
                                top: 0, 
                                bottom: 100,
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    const SizedBox(height: 10),
                                    // Dynamic Header based on selected mode
                                    Text(
                                        sessionMode == SessionMode.pomodoro ? 'Pomodoro Session' : 'Custom Session',
                                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: hpDeepBlue)),
                                    Text(
                                        sessionMode == SessionMode.pomodoro ? 'Configure your structured focus routine' : 'Set your own uninterrupted timing',
                                        style: TextStyle(fontSize: 16, color: secondaryTextGrey)),
                                    const SizedBox(height: 30),

                                    // MODE TOGGLE BUTTONS (Now correctly reflects initial selection)
                                    _buildModeToggle(),
                                    const SizedBox(height: 30),

                                    // CONDITIONAL DURATION SECTION
                                    AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        child: (sessionMode == SessionMode.pomodoro)
                                            ? Column(
                                                key: const ValueKey(SessionMode.pomodoro),
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text('Duration Options',
                                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
                                                    const SizedBox(height: 15),
                                                    _pomodoroDurationOption('25min', '+ 5 min break'),
                                                    _pomodoroDurationOption('50min', '+ 10 min break'),
                                                    const SizedBox(height: 30),
                                                    _pomodoroBlocksSlider(),
                                                ],
                                            )
                                            : Column(
                                                key: const ValueKey(SessionMode.custom),
                                                children: [_customDurationSlider()],
                                            ),
                                    ),
                                    
                                    const SizedBox(height: 30),

                                    // CONFIGURATION TOGGLE
                                    GestureDetector(
                                        onTap: () => setState(() => isConfigurationOpen = !isConfigurationOpen),
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                            decoration: BoxDecoration(
                                                color: softAccentHighlight,
                                                borderRadius: BorderRadius.circular(radius),
                                                border: Border.all(color: primaryColor.withOpacity(0.5)),
                                            ),
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                    Text('Rikaz Tools Configuration',
                                                        style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                                                    Icon(isConfigurationOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                        color: primaryColor, size: 24),
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
                                                key: const ValueKey('ConfigOpen'),
                                                padding: const EdgeInsets.only(top: 10),
                                                child: _configurationMenu(),
                                              )
                                            : const SizedBox.shrink(key: const ValueKey('ConfigClosed')),
                                    ),
                                ],
                            ),
                        ),

                        // Start button (fixed bottom)
                        Positioned(
                            left: globalHorizontalPadding,
                            right: globalHorizontalPadding,
                            bottom: 20,
                            child: ElevatedButton(
                                onPressed: isLoading ? null : handleStartSessionPress,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(radius)),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    elevation: 8,
                                    shadowColor: primaryColor.withOpacity(0.6),
                                ),
                                child: isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text(
                                        'Start Session',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
    
    Widget _buildModeToggle() {
        return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: softAccentHighlight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                children: [
                    _toggleButton(SessionMode.pomodoro, 'Pomodoro', Icons.timer),
                    const SizedBox(width: 8),
                    _toggleButton(SessionMode.custom, 'Custom Focus', Icons.tune),
                ],
            ),
        );
    }

    Widget _toggleButton(SessionMode mode, String text, IconData icon) {
        final isSelected = sessionMode == mode;
        final selectedColor = primaryColor;
        final unselectedColor = secondaryTextGrey;

        return Expanded(
            child: GestureDetector(
                onTap: () => setState(() {
                    sessionMode = mode;
                    // Keep existing durations when switching modes
                }),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: isSelected ? cardBackground : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(icon, size: 20, color: isSelected ? selectedColor : unselectedColor),
                            const SizedBox(width: 8),
                            Text(
                                text,
                                style: TextStyle(
                                    fontSize: 14,
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
}