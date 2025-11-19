import 'dart:async';
import 'dart:convert'; // ✅ ADD THIS for jsonEncode
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:rikazapp/services/rikaz_light_service.dart';
import 'package:rikazapp/widgets/rikaz_device_picker.dart';
import 'package:rikazapp/main.dart';

// ============================================================================
// FROSTED GLASS EFFECT WIDGET
// Used for sound controls UI with glassmorphism effect
// ============================================================================
class FrostedGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Color? borderColor;

  const FrostedGlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.6,
    this.borderRadius = 18,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final proportionalBorderRadius = screenWidth * 0.045;

    return ClipRRect(
      borderRadius: BorderRadius.circular(proportionalBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(proportionalBorderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// PLAY/PAUSE BUTTON WITH ANIMATION
// Animated button that transitions between play and pause states
// ============================================================================
class PlayAndPauseButton extends StatefulWidget {
  final Duration animationDuration;
  final Curve animationCurve;
  final VoidCallback onPressed;
  final bool isPaused;

  const PlayAndPauseButton({
    super.key,
    required this.onPressed,
    required this.isPaused,
    this.animationDuration = const Duration(milliseconds: 350),
    this.animationCurve = Curves.bounceIn,
  });

  @override
  State<PlayAndPauseButton> createState() => _PlayAndPauseButtonState();
}

class _PlayAndPauseButtonState extends State<PlayAndPauseButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.animationDuration);
    _animation = CurvedAnimation(parent: _controller!, curve: widget.animationCurve);
    _controller!.value = widget.isPaused ? 0.0 : 1.0;
  }

  @override
  void didUpdateWidget(covariant PlayAndPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused && _controller != null) {
      widget.isPaused ? _controller!.reverse() : _controller!.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final animation = _animation ?? kAlwaysCompleteAnimation;
    final color = widget.isPaused ? Colors.green : Colors.blue;

    return FloatingActionButton.extended(
      backgroundColor: color,
      onPressed: widget.onPressed,
      label: Row(
        children: [
          Text(
            widget.isPaused ? 'Resume' : 'Pause',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04),
          ),
          SizedBox(width: screenWidth * 0.015),
          AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: animation,
            color: Colors.white,
            size: screenWidth * 0.05,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MAIN SESSION PAGE
// Manages focus sessions with timer, Rikaz light control, and database tracking
// ============================================================================
class SessionPage extends StatefulWidget {
  final String sessionType;
  final String duration;
  final String? numberOfBlocks;
  
  // Future sprint parameters - camera detection, notifications, etc.
  final bool? isCameraDetectionEnabled;
  final double? sensitivity;
  final String? notificationStyle;
  final bool? rikazConnected;

  const SessionPage({
    super.key,
    required this.sessionType,
    required this.duration,
    this.numberOfBlocks,
    this.isCameraDetectionEnabled,
    this.sensitivity,
    this.notificationStyle,
    this.rikazConnected,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage>
    with SingleTickerProviderStateMixin {
  
  // ========== RIKAZ LIGHT CONNECTION STATE ==========
  bool _rikazConnected = false;        // Is ESP32 currently connected via BLE?
  bool _lightInitialized = false;      // Has initial light command been sent?

  // ========== SESSION CONFIGURATION ==========
  late bool isPomodoro;                // Pomodoro or Custom mode?
  late int focusMinutes;               // Length of focus periods
  late int breakMinutes;               // Length of break periods
  late int totalBlocks;                // Number of Pomodoro blocks

  // ========== DATABASE TRACKING ==========
  String? _currentSessionId;           // ID of session in database
  DateTime? _sessionStartTime;         // When session started
  int _totalFocusSeconds = 0;          // Total focused time (excludes breaks)

  // ========== SESSION STATE ==========
  String mode = 'focus';               // 'focus' or 'break'
  String status = 'running';           // 'running', 'paused', or 'idle'
  int currentBlock = 1;                // Which Pomodoro block we're on
  int timeLeft = 0;                    // Seconds remaining in current phase
  List<int> completedBlocks = [];      // Which blocks have been completed
  Timer? _timer;                       // Timer that counts down

  late AnimationController pulseController;  // For pulsing animation

  // ========== CONNECTION MONITORING ==========
  Timer? _connectionCheckTimer;        // Periodically checks ESP32 BLE connection

  // ========================================================================
  // SEND TIMER UPDATE TO ESP32 LCD
  // Syncs the countdown timer with the external LCD display
  // ========================================================================
Future<void> _sendTimerUpdateToESP32() async {
  if (!_rikazConnected || !_lightInitialized) {
    print('⏸️ RIKAZ: Skipping LCD update - device not connected');
    return;
  }
  
  final String currentStatus = status == 'running' ? 'running' : 'paused';
  final String currentMode = mode; // 'focus' or 'break'
  
  final Map<String, dynamic> timerCommand = {
    'timer': {
      'minutes': timeLeft ~/ 60,
      'seconds': timeLeft % 60,
      'status': currentStatus,
      'mode': currentMode,
    }
  };
  
  final String jsonCommand = jsonEncode(timerCommand);
  
  try {
    print('📺 RIKAZ: Sending to LCD: $jsonCommand');
    final bool success = await RikazLightService.sendCommand(jsonCommand);
    if (!success) {
      print('⚠️ RIKAZ: Failed to send timer update to LCD');
    } else {
      print('✅ RIKAZ: Timer sent to LCD: ${timeLeft ~/ 60}:${timeLeft % 60} ($currentStatus)');
    }
  } catch (e) {
    print('❌ RIKAZ: Error sending timer update: $e');
  }
}

// Add this method for positive reinforcement
Future<void> _sendMotivationalMessage() async {
  if (!_rikazConnected || !_lightInitialized) return;
  
  try {
    final String motivationCommand = jsonEncode({'motivation': 'show'});
    await RikazLightService.sendCommand(motivationCommand);
    print('💪 RIKAZ: Sent motivational message to LCD');
  } catch (e) {
    print('❌ RIKAZ: Error sending motivation: $e');
  }
}
  // ========================================================================
  // REUSABLE RESUME LOGIC
  // Handles light re-initialization and checks for failure before resuming.
  // ========================================================================
  Future<bool> _handleLightAndResume() async {
    if (!mounted) return false;
    
    bool success = true;

    // 1. Re-initialize light connection if lost
    if (RikazConnectionState.isConnected && !_lightInitialized) {
      if (mode == 'focus') {
        success = await RikazLightService.setFocusLight();
      } else if (mode == 'break') {
        success = await RikazLightService.setBreakLight();
      }
      
      if (success) {
        _rikazConnected = true;
        _lightInitialized = true;
        _startConnectionMonitoring();
        print('✅ RIKAZ: Lights re-initialized during resume attempt');
      }
    } 
    // 2. Ensure light is on if already initialized and connected
    else if (_rikazConnected && _lightInitialized) {
      if (mode == 'focus') {
        success = await RikazLightService.setFocusLight();
      } else if (mode == 'break') {
        success = await RikazLightService.setBreakLight();
      }
    }

    // 3. Handle light command failure
    if (!success && (_rikazConnected || _lightInitialized)) {
      print('⚠️ RIKAZ: Light command failed on resume, remaining paused.');
      return false; // Resume FAILED
    }

    // 4. Resume Timer/Animation
    setState(() {
      status = 'running';
    });
    pulseController.repeat(reverse: true);
    
    // 5. ✅ Update LCD with resumed state
    _sendTimerUpdateToESP32();
    
    print('▶️ RIKAZ: Session resumed');
    return true; // Resume SUCCESS
  }

  // ========================================================================
  // RECONNECTION HANDLER
  // Flow: Device picker → Connect → Resume via helper
  // Session is already paused before this is called
  // ========================================================================
  Future<void> _handleReconnectAttempt() async {
    if (!mounted) return;
    
    print('🔄 RIKAZ: Starting reconnection attempt...');
    
    // STEP 1: Show device picker - user selects Rikaz device
    final RikazDevice? selectedDevice = await showDialog<RikazDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(),
    );
    
    if (!mounted) return;
    
    // STEP 2: If device was successfully selected and connected
    if (selectedDevice != null) {
      RikazConnectionState.isConnected = true;
      _rikazConnected = true;
      
      // STEP 3: Restore light and resume
      final bool resumeSuccess = await _handleLightAndResume(); 
      
      // STEP 4: Show result notification
      if (mounted) {
        if (resumeSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Reconnected! Session resumed.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reconnected but light control failed. Please try again.'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('❌ RIKAZ: Reconnection cancelled. Session remains paused.');
    }
  }

  // ========================================================================
  // HANDLE LIGHT COMMAND FAILURE
  // Called when a light command fails during an active session
  // ========================================================================
  void _handleLightCommandFailure({bool showSnackbar = true}) {
    if (!mounted) return;
    
    // Pause the session immediately
    if (status == 'running') {
      setState(() {
        status = 'paused';
      });
      pulseController.stop();
      _sendTimerUpdateToESP32(); // ✅ Update LCD with paused state
      print('⏸️ RIKAZ: Session paused due to light command failure');
    }
    
    // Show notification with reconnect option
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Rikaz Light connection lost. Session paused.'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Reconnect',
            textColor: Colors.white,
            onPressed: () {
              // Pause session before reconnecting
              if (mounted && status == 'running') {
                setState(() {
                  status = 'paused';
                });
                pulseController.stop();
                _sendTimerUpdateToESP32(); // ✅ Update LCD with paused state
                print('⏸️ RIKAZ: Session paused via SnackBar Reconnect button');
              }
              _handleReconnectAttempt();
            },
          ),
        ),
      );
    }
    
    // Reset connection flags
    if (!RikazConnectionState.isConnected) {
      _rikazConnected = false;
      _lightInitialized = false;
      print('🔌 RIKAZ: Connection flags reset');
    }
  }

  // ========================================================================
  // START SESSION IN DATABASE
  // Creates a new session record when user starts focusing
  // ========================================================================
  Future<void> _startSessionInDB() async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      print('Error: User not authenticated. Cannot start session.');
      return;
    }

    final int finalPlannedDuration =
        isPomodoro ? (focusMinutes * totalBlocks) : focusMinutes;
    final String? pomodoroType =
        isPomodoro ? '$focusMinutes-$breakMinutes' : null;

    _sessionStartTime = DateTime.now();

    try {
      final response = await supabase.from('Focus_Session').insert({
        'user_id': currentUserId,
        'session_type': widget.sessionType,
        'start_time': _sessionStartTime!.toIso8601String(),
        'set_duration_minutes': finalPlannedDuration,
        'pomodoro_type': pomodoroType,
        'camera_monitored': widget.isCameraDetectionEnabled ?? false,
      }).select('session_id');

      if (response.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentSessionId = response.first['session_id'].toString();
          });
        }
        print('✅ Session Started in DB with ID: $_currentSessionId');
      }
    } catch (e) {
      print('❌ Error starting session in DB: $e');
    }
  }

  // ========================================================================
  // SHOW PROGRESS LEVEL DIALOG
  // Asks user how much they accomplished after session ends
  // ========================================================================
  Future<String?> _showProgressLevelDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.06),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3F6FF), Color(0xFFEEF2FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.track_changes,
                  size: screenWidth * 0.15,
                  color: const Color(0xFF6366F1),
                ),
                SizedBox(height: screenWidth * 0.04),
                Text(
                  'How much of your goal did you achieve in this session?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.048,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenWidth * 0.06),
                _buildProgressOption(
                  context,
                  level: 'fully',
                  title: 'Fully',
                  subtitle: 'I accomplished everything I set out to do',
                  icon: Icons.verified,
                  color: const Color(0xFF10B981),
                ),
                SizedBox(height: screenWidth * 0.03),
                _buildProgressOption(
                  context,
                  level: 'partially',
                  title: 'Partially',
                  subtitle: 'I made good progress but didn\'t finish',
                  icon: Icons.trending_up,
                  color: const Color(0xFFF59E0B),
                ),
                SizedBox(height: screenWidth * 0.03),
                _buildProgressOption(
                  context,
                  level: 'barely',
                  title: 'Barely',
                  subtitle: 'I struggled to stay focused',
                  icon: Icons.sentiment_dissatisfied,
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressOption(
    BuildContext context, {
    required String level,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: () => Navigator.of(context).pop(level),
      borderRadius: BorderRadius.circular(screenWidth * 0.035),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.035),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(screenWidth * 0.025),
              ),
              child: Icon(icon, color: color, size: screenWidth * 0.07),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: color, size: screenWidth * 0.04),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // END SESSION IN DATABASE
  // Updates session with final duration and progress when session completes
  // ========================================================================
  Future<void> _endSessionInDB({bool completed = false}) async {
    final supabase = Supabase.instance.client;

    if (_currentSessionId == null) {
      print('Error: Cannot end session. Session ID is missing.');
      return;
    }

    final int actualFocusDurationMinutes = (_totalFocusSeconds ~/ 60);

    // Don't save sessions shorter than 1 minute
    if (actualFocusDurationMinutes < 1) {
      print('❌ Session too short (<1 min). Not saved.');
      try {
        await supabase
            .from('Focus_Session')
            .delete()
            .eq('session_id', _currentSessionId!);
        print('🗑️ Short session deleted from DB.');
      } catch (e) {
        print('⚠️ Error deleting short session: $e');
      }
      return;
    }

    // Ask user about their progress
    String? progressLevel = await _showProgressLevelDialog();
    progressLevel ??= 'partially';

    final endDateTime = DateTime.now().toIso8601String();

    try {
      await supabase.from('Focus_Session').update({
        'end_time': endDateTime,
        'duration_minutes': actualFocusDurationMinutes,
        'progress_level': progressLevel,
      }).eq('session_id', _currentSessionId!);

      print('✅ Session ended. Duration: $actualFocusDurationMinutes min, Progress: $progressLevel');
    } catch (e) {
      print('❌ Error ending session in DB: $e');
    }
  }

  // ========================================================================
  // INITIALIZATION
  // Sets up session parameters and starts the timer
  // ========================================================================
  @override
  void initState() {
    super.initState();
    
    isPomodoro = widget.sessionType == 'pomodoro';

    if (isPomodoro) {
      if (widget.duration == '25min') {
        focusMinutes = 25;
        breakMinutes = 5;
      } else {
        focusMinutes = 50;
        breakMinutes = 10;
      }
      totalBlocks = int.tryParse(widget.numberOfBlocks ?? '4') ?? 4;
    } else {
      focusMinutes = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
      breakMinutes = 0;
      totalBlocks = 1;
    }

    _rikazConnected = widget.rikazConnected ?? false;

    timeLeft = focusMinutes * 60;
    startTimer();

    _startSessionInDB();

    // Send initial light command if ESP32 is connected
    if (_rikazConnected && !_lightInitialized) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && status == 'running') {
          bool success = await RikazLightService.setFocusLight();
          
          if (mounted && success) {
            _lightInitialized = true;
            _startConnectionMonitoring();
            _sendTimerUpdateToESP32(); // ✅ Send initial timer to LCD
            print('🔵 RIKAZ: Session started - Focus light ON');
          } else if (mounted && !success) {
            _handleLightCommandFailure();
            print('❌ RIKAZ: Initial light command failed. Session paused.');
          }
        }
      });
    } else if (!_rikazConnected) {
      print('⚠️ RIKAZ: Tools not connected, light control disabled');
    }

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  // ========================================================================
  // START CONNECTION MONITORING
  // Checks every 2 seconds if ESP32 is still connected via BLE
  // ========================================================================
  void _startConnectionMonitoring() {
  _connectionCheckTimer?.cancel();
  
  _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    if (!mounted || !RikazConnectionState.isConnected) {
      timer.cancel();
      return;
    }
    
    final bool stillConnected = await RikazLightService.isConnected();
    
    if (!stillConnected) {
      timer.cancel();
      
      await RikazLightService.disconnect();
      RikazConnectionState.isConnected = false;

      if (mounted) {
        // ✅ DON'T auto-pause - just update connection flags
        setState(() {
          _rikazConnected = false;
          _lightInitialized = false;
          // Remove automatic pausing - let session continue
        });
        
        print('⚠️ CONNECTION LOST - Session continues running (no auto-pause)');
        print('📊 Current status: $status (unchanged)');
      }
      
      // Show dialog when user opens app, but don't force pause
      _showDeviceLostWarning();
    }
  });
}


  // ========================================================================
  // SHOW DEVICE LOST WARNING
  // Alert dialog when BLE connection is lost during active session
  // ========================================================================
  void _showDeviceLostWarning() {
  if (!mounted) return;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.link_off, color: Colors.red.shade700, size: 48),
      title: const Text('Rikaz Tools Disconnected'),
      content: const Text(
        'The Bluetooth connection to your Rikaz device was lost.\n\n'
        'Your session is still running without external feedback.\n\n'
        'Click "Reconnect" to restore the connection.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue Without Rikaz'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context); // Close dialog first
            
            // ✅ NOW pause when user actively tries to reconnect
            if (mounted && status == 'running') {
              setState(() {
                status = 'paused';
              });
              if (pulseController.isAnimating) {
                pulseController.stop();
              }
              print('⏸️ RIKAZ: Session paused - User is reconnecting');
            }
            
            // Then attempt reconnection
            _handleReconnectAttempt();
          },
          icon: Icon(Icons.bluetooth_searching),
          label: const Text('Reconnect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
  
  debugPrint('⚠️ RIKAZ: BLE connection lost. Session continues running.');
}

  // ========================================================================
  // TIMER LOGIC
  // Manages countdown and phase transitions
  // ========================================================================
  
  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status != 'running') return;
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      if (timeLeft <= 1) {
        onPhaseEnd();
      } else {
        setState(() {
          timeLeft--;
          if (mode == 'focus') {
            _totalFocusSeconds++;
          }
        });
        
        // ✅ Send timer update to LCD every second
        _sendTimerUpdateToESP32();
      }
    });
  }

void onPhaseEnd() async { 
  if (!mounted) return;

  // CUSTOM SESSION: End when time is up
  if (!isPomodoro) {
    setState(() => status = 'idle');
    _timer?.cancel();

    // Send session completion message to LCD
    if (_rikazConnected && _lightInitialized) {
      final String completeCommand = jsonEncode({'sessionComplete': 'true'});
      await RikazLightService.sendCommand(completeCommand);
      
      bool success = await RikazLightService.turnOff();
      if (!success) {
        print('❌ RIKAZ: Final turnOff failed due to connection loss.');
      }
      print('⚫ RIKAZ: Custom session ended - Light OFF');
    }

    _endSessionInDB(completed: true);
    return;
  }

  // POMODORO SESSION: Switch between focus and break
  if (mode == 'focus') {
    if (!completedBlocks.contains(currentBlock)) {
      completedBlocks.add(currentBlock);
      _sendMotivationalMessage(); // ✅ Already implemented correctly
    }
    
    setState(() {
      mode = 'break';
      timeLeft = breakMinutes * 60;
    });

    if (_rikazConnected && _lightInitialized) {
      bool success = await RikazLightService.setBreakLight();
      if (mounted && !success) {
        _handleLightCommandFailure();
        return; 
      }
      _sendTimerUpdateToESP32(); // ✅ Update LCD for break mode
      print('🟡 RIKAZ: Break started - Break light ON');
    }
  } else {
    final next = currentBlock + 1;
    
    if (next > totalBlocks) {
      // All blocks complete - Send completion message
      if (_rikazConnected && _lightInitialized) {
        final String completeCommand = jsonEncode({'sessionComplete': 'true'});
        await RikazLightService.sendCommand(completeCommand);
        
        bool success = await RikazLightService.turnOff();
        if (!success) {
          print('❌ RIKAZ: Final turnOff failed due to connection loss.');
        }
        print('⚫ RIKAZ: Pomodoro complete - Light OFF');
      }
      
      setState(() {
        mode = 'focus';
        currentBlock = 1;
        completedBlocks.clear();
        timeLeft = focusMinutes * 60;
        status = 'idle';
      });
      _timer?.cancel();

      _endSessionInDB(completed: true);
    } else {
      // Start next block
      setState(() {
        currentBlock = next;
        mode = 'focus';
        timeLeft = focusMinutes * 60;
      });

      if (_rikazConnected && _lightInitialized) {
        bool success = await RikazLightService.setFocusLight();
        if (mounted && !success) {
          _handleLightCommandFailure();
          return; 
        }
        _sendTimerUpdateToESP32(); // ✅ Update LCD for focus mode
        print('🔵 RIKAZ: Focus resumed - Focus light ON');
      }
    }
  }
}

  // ========================================================================
  // PAUSE/RESUME HANDLER
  // Toggles between paused and running states
  // ========================================================================
  void onPauseResume() async {
    if (!mounted) return;
    
    final nextStatus = status == 'paused' ? 'running' : 'paused';
    
    // PAUSING: Just pause timer/animation
    if (nextStatus == 'paused') {
      setState(() { status = nextStatus; });
      pulseController.stop();
      _sendTimerUpdateToESP32(); // ✅ Update LCD with paused state
      print('⏸️ RIKAZ: Session manually paused (light remains ON)');
    } 
    // RESUMING: Use the robust helper
    else if (nextStatus == 'running') {
      await _handleLightAndResume(); // This already calls _sendTimerUpdateToESP32()
    }
  }

  // ========================================================================
  // QUIT SESSION HANDLER
  // Shows confirmation dialog before ending session
  // ========================================================================
  void onQuit() {
    final String previousStatus = status;
    
    setState(() => status = 'paused');
    if (pulseController.isAnimating) {
      pulseController.stop();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure you want to quit this session?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                setState(() => status = previousStatus);
                if (previousStatus == 'running') {
                  pulseController.repeat(reverse: true);
                }
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              _timer?.cancel();

              try {
                pulseController.dispose();
              } catch (_) {}

              if (_rikazConnected && _lightInitialized) {
                await RikazLightService.turnOff();
                print('⚫ RIKAZ: Session quit - Light OFF');
              }

              Navigator.pop(dialogContext);

              await _endSessionInDB(completed: false);

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/tabs',
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Quit',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void onGames() {
    Navigator.of(context).pushNamed('/games');
  }

  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get progress {
    final total = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
    return (1 - (timeLeft / max(total, 1))).clamp(0, 1);
  }

  // ========================================================================
  // CLEANUP
  // ========================================================================
  @override
  void dispose() {
    _timer?.cancel();
    _connectionCheckTimer?.cancel();

    if (_rikazConnected && _lightInitialized) {
      RikazLightService.turnOff();
      print('⚫ RIKAZ: Session disposed - Light OFF');
    }

    try {
      if (pulseController.isAnimating) pulseController.stop();
      pulseController.dispose();
    } catch (_) {}

    super.dispose();
  }

  // ========================================================================
  // UI BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.05;

    final bool isPaused = status == 'paused';
    final bool isBreak = mode == 'break';

    final gradientColors = isPaused
        ? const [
            Color.fromARGB(255, 225, 227, 230),
            Color.fromARGB(255, 185, 196, 207)
          ]
        : isBreak
          ? const [
              Color(0xFFFFF7ED),
              Color(0xFFFFFBEB),
              Color(0xFFFEF3C7)
            ]
          : const [
              Color(0xFFF3F6FF),
              Color(0xFFEEF2FF),
              Color(0xFFEDE9FE)
            ];

    final Color shadowColor = isPaused
        ? Colors.grey.withOpacity(0.3)
        : (isBreak
            ? const Color.fromARGB(160, 255, 172, 64).withOpacity(0.3)
            : const Color.fromARGB(78, 78, 52, 194).withOpacity(0.3));

    final timerOuterDiameter = screenWidth * 0.75;
    final timerInnerDiameter = screenWidth * 0.62;
    final controlContainerRadius = screenWidth * 0.045;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: screenHeight * 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Session type badge
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: screenHeight * 0.008),
                  decoration: BoxDecoration(
                    color: (isBreak ? Colors.orange : Colors.blue).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: screenWidth * 0.02,
                        height: screenWidth * 0.02,
                        margin: EdgeInsets.only(right: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: isBreak ? Colors.orange : Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Text(
                        isPomodoro
                            ? (isBreak ? 'Break Time' : 'Focus Session')
                            : 'Custom Session',
                        style: TextStyle(
                            color: isBreak ? Colors.orange[900] : Colors.blue[900],
                            fontWeight: FontWeight.w700,
                            fontSize: screenWidth * 0.035),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),

                // Circular timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: timerOuterDiameter,
                      height: timerOuterDiameter,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 40,
                            spreadRadius: 6,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: timerInnerDiameter,
                      height: timerInnerDiameter,
                      child: CustomPaint(
                        painter: _GradientRingPainter(
                          progress: progress,
                          isBreak: isBreak,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatTime(timeLeft),
                          style: TextStyle(
                            fontSize: screenWidth * 0.095,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.008),
                        Text(
                          isPaused
                              ? 'Paused'
                              : (isBreak ? 'Relax & recharge' : 'Stay focused'),
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: screenWidth * 0.032,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.05),

                // Control buttons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(controlContainerRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    children: [
                      Text(
                        isPomodoro
                            ? 'Block $currentBlock of $totalBlocks'
                            : 'Focus Duration',
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Row(
                        children: [
                          Expanded(
                            child: isBreak
                                ? ElevatedButton.icon(
                                      onPressed: onGames,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: EdgeInsets.symmetric(
                                            vertical: screenHeight * 0.018),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                screenWidth * 0.035)),
                                      ),
                                      icon: Icon(Icons.videogame_asset,
                                          color: Colors.white,
                                          size: screenWidth * 0.06),
                                      label: Text(
                                        'Games',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: screenWidth * 0.04),
                                      ),
                                    )
                                : PlayAndPauseButton(
                                      isPaused: isPaused,
                                      onPressed: onPauseResume,
                                    ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onQuit,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: screenHeight * 0.018),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      screenWidth * 0.035),
                                ),
                              ),
                              icon: Icon(Icons.stop,
                                  color: Colors.red, size: screenWidth * 0.06),
                              label: Text(
                                'Quit',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.04),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),

                // Pomodoro blocks or sound controls
                if (isPomodoro)
                  Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: screenWidth * 0.04,
                        runSpacing: screenWidth * 0.04,
                        children: List.generate(totalBlocks, (i) {
                          final blockNum = i + 1;
                          final isActive =
                              mode == 'focus' && currentBlock == blockNum;
                          final isCompleted = completedBlocks.contains(blockNum);
                          return _PomodoroBlock(
                            blockNum: blockNum,
                            isActive: isActive,
                            isCompleted: isCompleted,
                            isRunning: status == 'running',
                            controller: pulseController,
                          );
                        }),
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      const SoundSection(),
                    ],
                  )
                else
                  const SoundSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER FOR CIRCULAR PROGRESS RING
// ============================================================================
class _GradientRingPainter extends CustomPainter {
  final double progress;
  final bool isBreak;
  
  _GradientRingPainter({required this.progress, required this.isBreak});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final rect = Offset.zero & size;
    
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 2 * pi - pi / 2,
      colors: isBreak
          ? const [
              Color(0xFFFBBF24),
              Color(0xFFF59E0B),
              Color(0xFFF97316),
              Color(0xFFFBBF24),
            ]
          : const [
              Color(0xFF3B82F6),
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFF3B82F6),
            ],
      stops: const [0.0, 0.33, 0.66, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final bgPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// POMODORO BLOCK INDICATOR
// ============================================================================
class _PomodoroBlock extends StatelessWidget {
  final int blockNum;
  final bool isActive;
  final bool isCompleted;
  final bool isRunning;
  final AnimationController controller;

  const _PomodoroBlock({
    required this.blockNum,
    required this.isActive,
    required this.isCompleted,
    required this.isRunning,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final blockDiameter = screenWidth * 0.14;
    final blockFontSize = screenWidth * 0.04;

    final Color bgColor = isCompleted
        ? Colors.green
        : (isActive ? const Color.fromRGBO(33, 150, 243, 1) : Colors.white);

    final Color shadowColor = isCompleted
        ? Colors.green.withOpacity(0.35)
        : isActive
            ? Colors.blue.withOpacity(0.35)
            : Colors.black.withOpacity(0.15);

    return Column(
      children: [
        ScaleTransition(
          scale: isActive && isRunning
              ? Tween(begin: 1.0, end: 1.06).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Curves.easeInOut,
                  ),
                )
              : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: blockDiameter,
            height: blockDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? Icon(Icons.check,
                    color: Colors.white, size: screenWidth * 0.06)
                : Text(
                    '$blockNum',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: blockFontSize,
                    ),
                  ),
          ),
        ),
        SizedBox(height: screenHeight * 0.008),
        Text(
          isCompleted
              ? 'Done'
              : isActive
                  ? (isRunning ? 'Active' : 'Pending')
                  : 'Pending',
          style: TextStyle(
              fontSize: screenWidth * 0.03, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ============================================================================
// SOUND OPTIONS MODEL
// ============================================================================
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
      colorHex: '#64748B',
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
      default:
        return Icons.volume_off_rounded;
    }
  }

  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

// ============================================================================
// SOUND CONTROL SECTION
// ============================================================================
class SoundSection extends StatefulWidget {
  const SoundSection({super.key});

  @override
  State<SoundSection> createState() => _SoundSectionState();
}

class _SoundSectionState extends State<SoundSection> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Future<List<SoundOption>> _soundsFuture;
  late SoundOption _currentSound; 
  bool _isSoundPlaying = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _currentSound = SoundOption.off();
    _soundsFuture = _fetchSoundsFromDB();
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<List<SoundOption>> _fetchSoundsFromDB() async {
    try {
      final supabase = Supabase.instance.client;
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

      return fetchedSounds;
    } catch (e) {
      print('❌ Error fetching sounds: $e');
      return [SoundOption.off()];
    }
  }

  Future<void> _onSoundSelected(SoundOption selectedSound) async {
    if (!mounted) return;

    await _audioPlayer.stop();
    if (selectedSound.id == 'off' || selectedSound.filePathUrl == null) {
      setState(() { 
        _currentSound = SoundOption.off();
        _isSoundPlaying = false;
        _isExpanded = false;
      });
    } else {
      try {
        await _audioPlayer.play(UrlSource(selectedSound.filePathUrl!));
        setState(() {
          _currentSound = selectedSound;
          _isSoundPlaying = true;
          _isExpanded = false;
        });
      } catch (e) {
        print('Error playing sound from URL: $e');
        setState(() {
          _currentSound = SoundOption.off();
          _isSoundPlaying = false;
          _isExpanded = false;
        });
      }
    }
  }

  Future<void> _onPlayPauseTapped() async {
    if (_currentSound.id == 'off') return;

    if (_isSoundPlaying) {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() => _isSoundPlaying = false);
      }
    } else {
      await _audioPlayer.resume();
      if (mounted) {
        setState(() => _isSoundPlaying = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final displayIcon = _isSoundPlaying ? _currentSound.icon : Icons.volume_off_rounded;
    final displayColor = _isSoundPlaying ? _currentSound.color : const Color(0xFF64748B);
    final String displayText = _isSoundPlaying
        ? 'Playing: ${_currentSound.name}'
        : (_currentSound.id == 'off' ? 'Background Sound' : 'Paused: ${_currentSound.name}');

    return FrostedGlassContainer(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (!mounted) return;
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  Container(
                    width: screenWidth * 0.09,
                    height: screenWidth * 0.09,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                      color: displayColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      displayIcon,
                      color: displayColor,
                      size: screenWidth * 0.045,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                  ),
                  if (_currentSound.id != 'off')
                    Padding(
                      padding: EdgeInsets.only(right: screenWidth * 0.03),
                      child: IconButton(
                        icon: Icon(
                          _isSoundPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: displayColor,
                          size: screenWidth * 0.08,
                        ),
                        onPressed: _onPlayPauseTapped,
                      ),
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: screenWidth * 0.06,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color.fromRGBO(255, 255, 255, 0.4), thickness: 1),
                FutureBuilder<List<SoundOption>>(
                  future: _soundsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('Could not load sounds')),
                      );
                    }
                    if (snapshot.hasData) {
                      final sounds = snapshot.data!;
                      return Column(
                        children: sounds.map((sound) {
                          final bool isThisOneSelected =
                              sound.id == _currentSound.id && _isSoundPlaying;
                          return _SoundRow(
                            sound: sound,
                            isSelected: isThisOneSelected,
                            onTap: () => _onSoundSelected(sound),
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  final SoundOption sound;
  final bool isSelected;
  final VoidCallback onTap;

  const _SoundRow({
    required this.sound,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rowHorizontalPadding = screenWidth * 0.04;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rowHorizontalPadding, vertical: screenWidth * 0.03),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.08,
              height: screenWidth * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
                color: sound.color.withOpacity(0.15),
              ),
              child: Icon(
                sound.icon,
                color: sound.color,
                size: screenWidth * 0.045,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sound.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Colors.green.shade600,
                size: screenWidth * 0.05,
              ),
          ],
        ),
      ),
    );
  }
}