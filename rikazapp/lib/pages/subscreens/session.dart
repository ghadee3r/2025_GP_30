import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:rikazapp/services/rikaz_light_service.dart';
import 'package:rikazapp/widgets/rikaz_device_picker.dart';
import 'package:rikazapp/main.dart';

// ============================================================================
// THEME COLORS - Matching HomePage theme
// ============================================================================
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85);
const Color dfLightSeafoam = Color(0xFF87ACA3);
const Color dfDeepBlue = Color(0xFF162893);
const Color dfNavyIndigo = Color(0xFF0C1446);

const Color primaryThemeColor = dfDeepBlue;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;
const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);
const Color errorIndicatorRed = Color(0xFFE57373);

// Session-specific colors - SWAPPED FOR BETTER CONTRAST
const Color focusBgColor = lightestAccentColor; // Background uses darker dfDeepTeal
const Color breakBgColor = Color(0xFFE6B400); // Yellow for break
const Color pausedBgColor = Color(0xFF9E9E9E); // Gray for paused

// ============================================================================
// MAIN SESSION PAGE
// ============================================================================
class SessionPage extends StatefulWidget {
  final String sessionType;
  final String duration;
  final String? numberOfBlocks;
  final bool? isCameraDetectionEnabled;
  final double? sensitivity;
  final String? notificationStyle;
  final bool? rikazConnected;
  final String? selectedSoundId;
  final String? selectedSoundName;
  final String? selectedSoundUrl;

  const SessionPage({
    super.key,
    required this.sessionType,
    required this.duration,
    this.numberOfBlocks,
    this.isCameraDetectionEnabled,
    this.sensitivity,
    this.notificationStyle,
    this.rikazConnected,
    this.selectedSoundId,
    this.selectedSoundName,
    this.selectedSoundUrl,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage>
    with SingleTickerProviderStateMixin {
  
  // ========== RIKAZ LIGHT CONNECTION STATE ==========
  bool _rikazConnected = false;
  bool _lightInitialized = false;

  // ========== SESSION CONFIGURATION ==========
  late bool isPomodoro;
  late int focusMinutes;
  late int breakMinutes;
  late int totalBlocks;

  // ========== DATABASE TRACKING ==========
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  int _totalFocusSeconds = 0;

  // ========== SESSION STATE ==========
  String mode = 'focus';
  String status = 'running';
  int currentBlock = 1;
  int timeLeft = 0;
  List<int> completedBlocks = [];
  Timer? _timer;

  late AnimationController pulseController;

  // ========== CONNECTION MONITORING ==========
  Timer? _connectionCheckTimer;

  // ========== MINIMUM SESSION TIME ==========
  // UPDATED: Changed minimum to 10 minutes
  static const int minimumSessionMinutes = 10;

  // ========================================================================
  // SEND TIMER UPDATE TO ESP32 LCD
  // ========================================================================
  Future<void> _sendTimerUpdateToESP32() async {
    if (!_rikazConnected || !_lightInitialized) {
      print('⏸️ RIKAZ: Skipping LCD update - device not connected');
      return;
    }
    
    final String currentStatus = status == 'running' ? 'running' : 'paused';
    final String currentMode = mode;
    
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
  // ========================================================================
  Future<bool> _handleLightAndResume() async {
    if (!mounted) return false;
    
    bool success = true;

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
    } else if (_rikazConnected && _lightInitialized) {
      if (mode == 'focus') {
        success = await RikazLightService.setFocusLight();
      } else if (mode == 'break') {
        success = await RikazLightService.setBreakLight();
      }
    }

    if (!success && (_rikazConnected || _lightInitialized)) {
      print('⚠️ RIKAZ: Light command failed on resume, remaining paused.');
      return false;
    }

    setState(() {
      status = 'running';
    });
    pulseController.repeat(reverse: true);
    
    _sendTimerUpdateToESP32();
    
    print('▶️ RIKAZ: Session resumed');
    return true;
  }

  // ========================================================================
  // RECONNECTION HANDLER
  // ========================================================================
  Future<void> _handleReconnectAttempt() async {
    if (!mounted) return;
    
    print('🔄 RIKAZ: Starting reconnection attempt...');
    
    final RikazDevice? selectedDevice = await showDialog<RikazDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(),
    );
    
    if (!mounted) return;
    
    if (selectedDevice != null) {
      RikazConnectionState.isConnected = true;
      _rikazConnected = true;
      
      final bool resumeSuccess = await _handleLightAndResume();
      
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
  // ========================================================================
  void _handleLightCommandFailure({bool showSnackbar = true}) {
    if (!mounted) return;
    
    if (status == 'running') {
      setState(() {
        status = 'paused';
      });
      pulseController.stop();
      _sendTimerUpdateToESP32();
      print('⏸️ RIKAZ: Session paused due to light command failure');
    }
    
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
              if (mounted && status == 'running') {
                setState(() {
                  status = 'paused';
                });
                pulseController.stop();
                _sendTimerUpdateToESP32();
                print('⏸️ RIKAZ: Session paused via SnackBar Reconnect button');
              }
              _handleReconnectAttempt();
            },
          ),
        ),
      );
    }
    
    if (!RikazConnectionState.isConnected) {
      _rikazConnected = false;
      _lightInitialized = false;
      print('🔌 RIKAZ: Connection flags reset');
    }
  }

  // ========================================================================
  // START SESSION IN DATABASE - UPDATED COLUMN NAME
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
        // Renamed column
        'planned_duration': finalPlannedDuration,
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
  // SHOW PROGRESS LEVEL DIALOG - Updated with new theme
  // ========================================================================
  Future<String?> _showProgressLevelDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.06),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: accentThemeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.track_changes,
                    size: screenWidth * 0.15,
                    color: accentThemeColor,
                  ),
                ),
                SizedBox(height: screenWidth * 0.04),
                Text(
                  'Session Complete!',
                  style: TextStyle(
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  'How much of your goal did you achieve?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    color: secondaryTextGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenWidth * 0.06),
                _buildProgressOption(
                  context,
                  level: 'fully',
                  title: 'Fully Achieved',
                  subtitle: 'Completed everything I set out to do',
                  icon: Icons.verified,
                  color: const Color(0xFF10B981),
                ),
                SizedBox(height: screenWidth * 0.03),
                _buildProgressOption(
                  context,
                  level: 'partially',
                  title: 'Partially Done',
                  subtitle: 'Made good progress but didn\'t finish',
                  icon: Icons.trending_up,
                  color: const Color(0xFFF59E0B),
                ),
                SizedBox(height: screenWidth * 0.03),
                _buildProgressOption(
                  context,
                  level: 'barely',
                  title: 'Barely Started',
                  subtitle: 'Struggled to stay focused',
                  icon: Icons.sentiment_dissatisfied,
                  color: errorIndicatorRed,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(level),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.025),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: screenWidth * 0.06),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.042,
                        fontWeight: FontWeight.bold,
                        color: primaryTextDark,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: secondaryTextGrey,
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
      ),
    );
  }

  // ========================================================================
  // END SESSION IN DATABASE - UPDATED COLUMNS AND MINIMUM DURATION CHECK
  // ========================================================================
  Future<void> _endSessionInDB({bool completed = false}) async {
    final supabase = Supabase.instance.client;

    if (_currentSessionId == null) {
      print('Error: Cannot end session. Session ID is missing.');
      return;
    }

    final int actualFocusDurationMinutes = (_totalFocusSeconds ~/ 60);

    // UPDATED: Check against the new 10-minute minimum
    if (actualFocusDurationMinutes < minimumSessionMinutes) {
      print('❌ Session too short (<$minimumSessionMinutes min). Not saved.');
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

    String? progressLevel = await _showProgressLevelDialog();
    progressLevel ??= 'partially';

    final endDateTime = DateTime.now().toIso8601String();

    try {
      await supabase.from('Focus_Session').update({
        'end_time': endDateTime,
        // Renamed column
        'actual_duration': actualFocusDurationMinutes,
        'progress_level': progressLevel,
      }).eq('session_id', _currentSessionId!);

      print('✅ Session ended. Duration: $actualFocusDurationMinutes min, Progress: $progressLevel');
    } catch (e) {
      print('❌ Error ending session in DB: $e');
    }
  }

  // ========================================================================
  // INITIALIZATION
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

    if (_rikazConnected && !_lightInitialized) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && status == 'running') {
          bool success = await RikazLightService.setFocusLight();
          
          if (mounted && success) {
            _lightInitialized = true;
            _startConnectionMonitoring();
            _sendTimerUpdateToESP32();
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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  // ========================================================================
  // START CONNECTION MONITORING
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
          setState(() {
            _rikazConnected = false;
            _lightInitialized = false;
          });
          
          print('⚠️ CONNECTION LOST - Session continues running (no auto-pause)');
          print('📊 Current status: $status (unchanged)');
        }
        
        _showDeviceLostWarning();
      }
    });
  }

  // ========================================================================
  // SHOW DEVICE LOST WARNING
  // ========================================================================
  void _showDeviceLostWarning() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardBackground,
        icon: Icon(Icons.link_off, color: errorIndicatorRed, size: 48),
        title: Text(
          'Rikaz Tools Disconnected',
          style: TextStyle(color: primaryTextDark, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'The Bluetooth connection to your Rikaz device was lost.\n\n'
          'Your session is still running without external feedback.\n\n'
          'Click "Reconnect" to restore the connection.',
          style: TextStyle(color: secondaryTextGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Without Rikaz',
              style: TextStyle(color: secondaryTextGrey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              
              if (mounted && status == 'running') {
                setState(() {
                  status = 'paused';
                });
                if (pulseController.isAnimating) {
                  pulseController.stop();
                }
                print('⏸️ RIKAZ: Session paused - User is reconnecting');
              }
              
              _handleReconnectAttempt();
            },
            icon: Icon(Icons.bluetooth_searching),
            label: const Text('Reconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentThemeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
    
    debugPrint('⚠️ RIKAZ: BLE connection lost. Session continues running.');
  }

  // ========================================================================
  // TIMER LOGIC
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
        
        _sendTimerUpdateToESP32();
      }
    });
  }

  void onPhaseEnd() async { 
    if (!mounted) return;

    if (!isPomodoro) {
      setState(() => status = 'idle');
      _timer?.cancel();

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

    if (mode == 'focus') {
      if (!completedBlocks.contains(currentBlock)) {
        completedBlocks.add(currentBlock);
        _sendMotivationalMessage();
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
        _sendTimerUpdateToESP32();
        print('🟡 RIKAZ: Break started - Break light ON');
      }
    } else {
      final next = currentBlock + 1;
      
      if (next > totalBlocks) {
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
          _sendTimerUpdateToESP32();
          print('🔵 RIKAZ: Focus resumed - Focus light ON');
        }
      }
    }
  }

  // ========================================================================
  // PAUSE/RESUME HANDLER
  // ========================================================================
  void onPauseResume() async {
    if (!mounted) return;
    
    final nextStatus = status == 'paused' ? 'running' : 'paused';
    
    if (nextStatus == 'paused') {
      setState(() { status = nextStatus; });
      pulseController.stop();
      _sendTimerUpdateToESP32();
      print('⏸️ RIKAZ: Session manually paused (light remains ON)');
    } else if (nextStatus == 'running') {
      await _handleLightAndResume();
    }
  }

  // ========================================================================
  // QUIT SESSION HANDLER - UPDATED WITH 10 MINUTE WARNING
  // ========================================================================
  void onQuit() {
    final String previousStatus = status;
    
    setState(() => status = 'paused');
    if (pulseController.isAnimating) {
      pulseController.stop();
    }

    if (!mounted) return;

    final int actualFocusDurationMinutes = (_totalFocusSeconds ~/ 60);
    final bool belowMinimum = actualFocusDurationMinutes < minimumSessionMinutes;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardBackground,
        title: Row(
          children: [
            Icon(
              belowMinimum ? Icons.warning_amber_rounded : Icons.exit_to_app,
              color: belowMinimum ? Colors.orange : errorIndicatorRed,
              size: 28,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                belowMinimum ? 'Session Too Short' : 'End Session?',
                style: TextStyle(fontSize: 20, color: primaryTextDark, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          // Updated message for 10-minute check
          belowMinimum 
              ? 'You\'ve only focused for $actualFocusDurationMinutes minutes. Sessions under $minimumSessionMinutes minutes won\'t be saved for future analysis.\n\nAre you sure you want to quit?'
              : 'Are you sure you want to end this session? Your progress will be saved.',
          style: TextStyle(color: secondaryTextGrey, height: 1.4),
        ),
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
            child: Text(
              'Continue Session',
              style: TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: errorIndicatorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(belowMinimum ? 'Quit Anyway' : 'End Session'),
          ),
        ],
      ),
    );
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
  // GET BACKGROUND COLOR BASED ON STATE
  // ========================================================================
  Color get backgroundColor {
    if (status == 'paused') return pausedBgColor;
    if (mode == 'break') return const Color.fromARGB(255, 247, 181, 0);
    return focusBgColor; // Now dfDeepTeal (darker background)
  }

  Color get ringColor {
    if (status == 'paused') return pausedBgColor.withOpacity(0.6);
    if (mode == 'break') return const Color.fromARGB(255, 255, 169, 8);
    return accentThemeColor; // Using accentThemeColor (lighter teal) for better contrast
  }

  // ========================================================================
  // UI BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool isPaused = status == 'paused';
    final bool isBreak = mode == 'break';

    final timerDiameter = screenWidth * 0.75;

    return Scaffold(
      body: Stack(
        children: [
          // Top colored section (full background)
          Container(
            color: backgroundColor,
          ),
          
          // Bottom white section with fully circular/rounded top
          Positioned(
            top: screenHeight * 0.38,
            left: -screenWidth * 0.5,
            right: -screenWidth * 0.5,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(screenWidth * 1.5),
                  topRight: Radius.circular(screenWidth * 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
            ),
          ),

          // Main scrollable content
          SafeArea(
            child: Column(
              children: [
                // Fixed top section with timer and buttons
                Column(
                  children: [
                    SizedBox(height: screenHeight * 0.05),

                    // Session Type Label
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenHeight * 0.012,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPomodoro
                            ? (isBreak ? 'Break Time' : 'Pomodoro Focus')
                            : 'Custom Session',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // Circular Timer with enhanced shadow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer white circle with shadow
                        Container(
                          width: timerDiameter,
                          height: timerDiameter,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 35,
                                spreadRadius: 5,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                        // Progress ring
                        SizedBox(
                          width: timerDiameter * 0.92,
                          height: timerDiameter * 0.92,
                          child: CustomPaint(
                            painter: _ProgressRingPainter(
                              progress: progress,
                              color: ringColor,
                            ),
                          ),
                        ),
                        // Time and info
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatTime(timeLeft),
                              style: TextStyle(
                                fontSize: screenWidth * 0.13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextDark,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            // Block counter for Pomodoro
                            if (isPomodoro && !isBreak)
                              Text(
                                '$currentBlock/$totalBlocks Sessions',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else if (isBreak)
                              Text(
                                'Take a rest',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              Text(
                                'Stay focused',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // Control Buttons
                    if (!isBreak)
                      Container(
                        decoration: BoxDecoration(
                          color: isPaused ? pausedBgColor : accentThemeColor, // accentThemeColor when running, gray when paused
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: onPauseResume,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.08,
                                vertical: screenWidth * 0.038,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPaused ? Icons.play_arrow : Icons.pause,
                                    color: Colors.white,
                                    size: screenWidth * 0.06,
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    isPaused ? 'Resume' : 'Pause',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      // Games button during break
                      Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => Navigator.of(context).pushNamed('/games'),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.08,
                                vertical: screenWidth * 0.038,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videogame_asset,
                                    color: Colors.white,
                                    size: screenWidth * 0.06,
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    'Play Games',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: screenHeight * 0.02),

                    // End Session Button
                    Container(
                      decoration: BoxDecoration(
                        color: errorIndicatorRed,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: onQuit,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.08,
                              vertical: screenWidth * 0.038,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: screenWidth * 0.05,
                                ),
                                SizedBox(width: screenWidth * 0.015),
                                Text(
                                  'End Session',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),

                // Sound Section - scrollable if needed
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          child: SoundSection(
                            preselectedSoundId: widget.selectedSoundId,
                            preselectedSoundName: widget.selectedSoundName,
                            preselectedSoundUrl: widget.selectedSoundUrl,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROGRESS RING PAINTER
// ============================================================================
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final rect = Offset.zero & size;

    final paint = Paint()
      ..color = color
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
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
// SOUND CONTROL SECTION - UPDATED TO AUTO-PLAY PRESELECTED SOUND
// ============================================================================
class SoundSection extends StatefulWidget {
  final String? preselectedSoundId;
  final String? preselectedSoundName;
  final String? preselectedSoundUrl;
  
  const SoundSection({
    super.key,
    this.preselectedSoundId,
    this.preselectedSoundName,
    this.preselectedSoundUrl,
  });

  @override
  State<SoundSection> createState() => _SoundSectionState();
}

class _SoundSectionState extends State<SoundSection> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Future<List<SoundOption>> _soundsFuture;
  late SoundOption _currentSound;
  bool _isSoundPlaying = false;
  bool _isExpanded = false;
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // Debug logging
    print('🎵 SoundSection init:');
    print('   - preselectedSoundId: ${widget.preselectedSoundId}');
    print('   - preselectedSoundName: ${widget.preselectedSoundName}');
    print('   - preselectedSoundUrl: ${widget.preselectedSoundUrl}');
    
    // Initialize with preselected sound or off
    if (widget.preselectedSoundId != null && 
        widget.preselectedSoundId != 'off' &&
        widget.preselectedSoundUrl != null) {
      _currentSound = SoundOption(
        id: widget.preselectedSoundId!,
        name: widget.preselectedSoundName ?? widget.preselectedSoundId!,
        filePathUrl: widget.preselectedSoundUrl,
        iconName: 'water_drop_outlined',
        colorHex: '#287C85',
      );
      
      print('🎵 Initialized with sound: ${_currentSound.name}');
      
      // Auto-play the preselected sound
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasAutoPlayed) {
          _autoPlayPreselectedSound();
        }
      });
    } else {
      _currentSound = SoundOption.off();
      print('🎵 Initialized with no sound (off)');
    }
    
    _soundsFuture = _fetchSoundsFromDB();
  }

  Future<void> _autoPlayPreselectedSound() async {
    if (_hasAutoPlayed || _currentSound.id == 'off' || _currentSound.filePathUrl == null) {
      return;
    }
    
    try {
      await _audioPlayer.play(UrlSource(_currentSound.filePathUrl!));
      if (mounted) {
        setState(() {
          _isSoundPlaying = true;
          _hasAutoPlayed = true;
        });
      }
      print('🎵 AUTO-PLAY: Started playing ${_currentSound.name}');
    } catch (e) {
      print('❌ Error auto-playing sound: $e');
      if (mounted) {
        setState(() {
          _currentSound = SoundOption.off();
          _isSoundPlaying = false;
          _hasAutoPlayed = true;
        });
      }
    }
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

      // Update current sound with proper icon and color if it matches fetched data
      if (_currentSound.id != 'off') {
        final matchingSound = fetchedSounds.firstWhere(
          (s) => s.id == _currentSound.id,
          orElse: () => _currentSound,
        );
        if (mounted && matchingSound.id == _currentSound.id) {
          setState(() {
            _currentSound = matchingSound;
          });
        }
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
        print('🎵 Playing: ${selectedSound.name}');
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
      print('⏸️ Paused: ${_currentSound.name}');
    } else {
      await _audioPlayer.resume();
      if (mounted) {
        setState(() => _isSoundPlaying = true);
      }
      print('▶️ Resumed: ${_currentSound.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Always show current sound's icon and color if it's not 'off'
    final displayIcon = _currentSound.id != 'off' ? _currentSound.icon : Icons.volume_off_rounded;
    final displayColor = _currentSound.id != 'off' ? _currentSound.color : secondaryTextGrey;
    // Show actual sound name when a sound is selected (not 'off'), otherwise show "Background Sound"
    final String displayText = _currentSound.id != 'off' && _currentSound.name.isNotEmpty
        ? _currentSound.name
        : 'Background Sound';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (!mounted) return;
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                width: screenWidth * 0.09,
                height: screenWidth * 0.09,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
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
                    color: primaryTextDark,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              if (_currentSound.id != 'off')
                IconButton(
                  icon: Icon(
                    _isSoundPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: displayColor,
                    size: screenWidth * 0.07,
                  ),
                  onPressed: _onPlayPauseTapped,
                ),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: secondaryTextGrey,
                size: screenWidth * 0.06,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Divider(height: 1, color: secondaryTextGrey.withOpacity(0.2), thickness: 1),
              FutureBuilder<List<SoundOption>>(
                future: _soundsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Center(child: CircularProgressIndicator(color: accentThemeColor)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Center(
                        child: Text(
                          'Could not load sounds',
                          style: TextStyle(color: secondaryTextGrey),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasData) {
                    final sounds = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sounds.length,
                      itemBuilder: (context, index) {
                        final sound = sounds[index];
                        final bool isThisOneSelected =
                            sound.id == _currentSound.id && _isSoundPlaying;
                        return _SoundRow(
                          sound: sound,
                          isSelected: isThisOneSelected,
                          onTap: () => _onSoundSelected(sound),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ],
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenWidth * 0.03),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.08,
              height: screenWidth * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: sound.color.withOpacity(0.1),
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
                  color: primaryTextDark,
                  fontSize: screenWidth * 0.037,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accentThemeColor,
                size: screenWidth * 0.05,
              ),
          ],
        ),
      ),
    );
  }
}