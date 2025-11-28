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
// THEME COLORS
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

const Color focusBgColor = lightestAccentColor;
const Color breakBgColor = Color(0xFFE6B400);
const Color pausedBgColor = Color(0xFF9E9E9E);

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

  // ========== COMPLETION FLAGS - CRITICAL FIX ==========
  bool _completionHandled = false;
  bool _isShowingProgressDialog = false;
  bool _isNavigatingAway = false;

  // ========== LIGHT CONTROL DEBOUNCING - CRITICAL FIX ==========
  DateTime? _lastLightOffTime;
  static const Duration _lightDebounceDelay = Duration(seconds: 2);

  // ========== MINIMUM SESSION TIME ==========
  static const int minimumSessionMinutes = 10;

  // ========================================================================
  // DEBOUNCED LIGHT OFF - PREVENTS SPAM
  // ========================================================================
  Future<void> _debouncedLightOff() async {
    if (!_rikazConnected || !_lightInitialized) {
      debugPrint('⏸️ RIKAZ: Skipping light off - device not connected');
      return;
    }

    final now = DateTime.now();
    
    // Debounce: Prevent rapid repeated calls
    if (_lastLightOffTime != null && 
        now.difference(_lastLightOffTime!) < _lightDebounceDelay) {
      debugPrint('⚠️ Light off debounced (too soon - ${now.difference(_lastLightOffTime!).inMilliseconds}ms)');
      return;
    }
    
    _lastLightOffTime = now;
    
    try {
      bool success = await RikazLightService.turnOff();
      if (success) {
        debugPrint('⚫ RIKAZ: Light turned OFF');
      } else {
        debugPrint('❌ RIKAZ: Light off failed');
      }
    } catch (e) {
      debugPrint('❌ RIKAZ: Light off error: $e');
    }
  }

  // ========================================================================
  // SEND TIMER UPDATE TO ESP32 LCD
  // ========================================================================
  Future<void> _sendTimerUpdateToESP32() async {
    if (!_rikazConnected || !_lightInitialized) {
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
      final bool success = await RikazLightService.sendCommand(jsonCommand);
      if (success) {
        debugPrint('✅ RIKAZ: Timer sent to LCD: ${timeLeft ~/ 60}:${timeLeft % 60} ($currentStatus)');
      }
    } catch (e) {
      debugPrint('❌ RIKAZ: Error sending timer update: $e');
    }
  }

  Future<void> _sendMotivationalMessage() async {
    if (!_rikazConnected || !_lightInitialized) return;
    
    try {
      final String motivationCommand = jsonEncode({'motivation': 'show'});
      await RikazLightService.sendCommand(motivationCommand);
      debugPrint('💪 RIKAZ: Sent motivational message');
    } catch (e) {
      debugPrint('❌ RIKAZ: Error sending motivation: $e');
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
        debugPrint('✅ RIKAZ: Lights re-initialized during resume');
      }
    } else if (_rikazConnected && _lightInitialized) {
      if (mode == 'focus') {
        success = await RikazLightService.setFocusLight();
      } else if (mode == 'break') {
        success = await RikazLightService.setBreakLight();
      }
    }

    if (!success && (_rikazConnected || _lightInitialized)) {
      debugPrint('⚠️ RIKAZ: Light command failed on resume');
      return false;
    }

    setState(() {
      status = 'running';
    });
    pulseController.repeat(reverse: true);
    
    _sendTimerUpdateToESP32();
    
    debugPrint('▶️ Session resumed');
    return true;
  }

  // ========================================================================
  // RECONNECTION HANDLER
  // ========================================================================
  Future<void> _handleReconnectAttempt() async {
    if (!mounted) return;
    
    debugPrint('🔄 RIKAZ: Starting reconnection...');
    
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
                  Expanded(child: Text('Reconnected! Session resumed.')),
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
              content: Text('Reconnected but light control failed.'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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
      debugPrint('⏸️ Session paused due to light failure');
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
                setState(() => status = 'paused');
                pulseController.stop();
                _sendTimerUpdateToESP32();
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
    }
  }

  // ========================================================================
  // START SESSION IN DATABASE
  // ========================================================================
  Future<void> _startSessionInDB() async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      debugPrint('Error: User not authenticated');
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
        debugPrint('✅ Session Started in DB: $_currentSessionId');
      }
    } catch (e) {
      debugPrint('❌ Error starting session in DB: $e');
    }
  }

  // ========================================================================
  // SHOW PROGRESS LEVEL DIALOG - FIXED WITH PREVENTION FLAGS
  // ========================================================================
  Future<String?> _showProgressLevelDialog() async {
    // CRITICAL: Prevent multiple dialogs
    if (_isShowingProgressDialog) {
      debugPrint('⚠️ Progress dialog already showing');
      return null;
    }

    debugPrint('📊 Showing progress dialog');
    _isShowingProgressDialog = true;

    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final screenWidth = MediaQuery.of(dialogContext).size.width;

          return WillPopScope(
            onWillPop: () async => false, // Prevent back button
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      child: Icon(Icons.track_changes, size: screenWidth * 0.15, color: accentThemeColor),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Text('Session Complete!', style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: primaryTextDark,
                    ), textAlign: TextAlign.center),
                    SizedBox(height: screenWidth * 0.02),
                    Text('How much of your goal did you achieve?', style: TextStyle(
                      fontSize: screenWidth * 0.038,
                      color: secondaryTextGrey,
                    ), textAlign: TextAlign.center),
                    SizedBox(height: screenWidth * 0.06),
                    _buildProgressOption(dialogContext,
                      level: 'fully',
                      title: 'Fully Achieved',
                      subtitle: 'Completed everything',
                      icon: Icons.verified,
                      color: const Color(0xFF10B981),
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    _buildProgressOption(dialogContext,
                      level: 'partially',
                      title: 'Partially Done',
                      subtitle: 'Made good progress',
                      icon: Icons.trending_up,
                      color: const Color(0xFFF59E0B),
                    ),
                    SizedBox(height: screenWidth * 0.03),
                    _buildProgressOption(dialogContext,
                      level: 'barely',
                      title: 'Barely Started',
                      subtitle: 'Struggled to focus',
                      icon: Icons.sentiment_dissatisfied,
                      color: errorIndicatorRed,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      return result;
    } catch (e) {
      debugPrint('❌ Progress dialog error: $e');
      return null;
    } finally {
      if (mounted) {
        _isShowingProgressDialog = false;
      }
    }
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
                    Text(title, style: TextStyle(
                      fontSize: screenWidth * 0.042,
                      fontWeight: FontWeight.bold,
                      color: primaryTextDark,
                    )),
                    SizedBox(height: screenWidth * 0.01),
                    Text(subtitle, style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: secondaryTextGrey,
                    )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: screenWidth * 0.04),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // END SESSION IN DATABASE - FIXED WITH COMPLETION FLAGS
  // ========================================================================
  Future<void> _endSessionInDB({bool completed = false}) async {
    // CRITICAL: Prevent multiple executions
    if (_completionHandled) {
      debugPrint('⚠️ Session completion already handled');
      return;
    }

    final supabase = Supabase.instance.client;

    if (_currentSessionId == null) {
      debugPrint('❌ Cannot end session. Session ID missing');
      return;
    }

    final int actualFocusDurationMinutes = (_totalFocusSeconds ~/ 60);

    // Check minimum duration FIRST - before setting flag
    if (actualFocusDurationMinutes < minimumSessionMinutes) {
      debugPrint('❌ Session too short (<$minimumSessionMinutes min). Deleting.');
      
      // Mark as handled BEFORE deletion
      _completionHandled = true;
      
      try {
        await supabase
            .from('Focus_Session')
            .delete()
            .eq('session_id', _currentSessionId!);
        debugPrint('🗑️ Short session deleted (ID: $_currentSessionId)');
      } catch (e) {
        debugPrint('⚠️ Error deleting short session: $e');
      }
      return;
    }

    // Mark as handled BEFORE showing dialog (prevents multiple dialogs)
    _completionHandled = true;
    
    debugPrint('💾 Ending session (ID: $_currentSessionId, Duration: $actualFocusDurationMinutes min)');

    String? progressLevel = await _showProgressLevelDialog();
    progressLevel ??= 'partially';

    final endDateTime = DateTime.now().toIso8601String();

    try {
      await supabase.from('Focus_Session').update({
        'end_time': endDateTime,
        'actual_duration': actualFocusDurationMinutes,
        'progress_level': progressLevel,
      }).eq('session_id', _currentSessionId!);

      debugPrint('✅ Session saved: Duration=$actualFocusDurationMinutes min, Progress=$progressLevel');
    } catch (e) {
      debugPrint('❌ Error updating session in DB: $e');
      // Don't reset flag on error - session is still "handled"
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
            debugPrint('🔵 RIKAZ: Focus light ON');
          } else if (mounted && !success) {
            _handleLightCommandFailure();
          }
        }
      });
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
          
          debugPrint('⚠️ Connection lost - session continues');
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
        title: Text('Rikaz Tools Disconnected',
          style: TextStyle(color: primaryTextDark, fontWeight: FontWeight.bold)),
        content: Text(
          'The Bluetooth connection was lost.\n\n'
          'Your session is still running.\n\n'
          'Click "Reconnect" to restore the connection.',
          style: TextStyle(color: secondaryTextGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Without', style: TextStyle(color: secondaryTextGrey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (mounted && status == 'running') {
                setState(() => status = 'paused');
                if (pulseController.isAnimating) pulseController.stop();
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

      setState(() {
        timeLeft--;
        if (mode == 'focus') {
          _totalFocusSeconds++;
        }
      });
      
      _sendTimerUpdateToESP32();

      if (timeLeft <= 0) {
        onPhaseEnd();
      }
    });
  }

  // ========================================================================
  // PHASE END - FIXED WITH COMPLETION FLAGS
  // ========================================================================
  void onPhaseEnd() async { 
    if (!mounted) return;

    // CRITICAL: Prevent multiple executions
    if (_completionHandled) {
      debugPrint('⚠️ Phase end already handled');
      return;
    }

    if (!isPomodoro) {
      // Custom session end
      _timer?.cancel();
      
      setState(() => status = 'idle');

      if (_rikazConnected && _lightInitialized) {
        final String completeCommand = jsonEncode({'sessionComplete': 'true'});
        await RikazLightService.sendCommand(completeCommand);
        await _debouncedLightOff();
        debugPrint('⚫ Custom session ended');
      }

      await _endSessionInDB(completed: true);
      
      // Navigate away
      if (mounted && !_isNavigatingAway) {
        _isNavigatingAway = true;
        Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false);
      }
      return;
    }

    // Pomodoro logic
    if (mode == 'focus') {
      if (!completedBlocks.contains(currentBlock)) {
        completedBlocks.add(currentBlock);
        _sendMotivationalMessage();
      }
      
      // Check if this is the last block
      if (currentBlock >= totalBlocks) {
        // Session complete
        _timer?.cancel();
        
        setState(() {
          mode = 'focus';
          status = 'idle';
        });

        if (_rikazConnected && _lightInitialized) {
          final String completeCommand = jsonEncode({'sessionComplete': 'true'});
          await RikazLightService.sendCommand(completeCommand);
          await _debouncedLightOff();
          debugPrint('⚫ Pomodoro complete');
        }
        
        await _endSessionInDB(completed: true);
        
        // Navigate away
        if (mounted && !_isNavigatingAway) {
          _isNavigatingAway = true;
          Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false);
        }
        return;
      }
      
      // Not last block, take break
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
        debugPrint('🟡 Break started');
      }
    } else {
      // Break over, next focus
      setState(() {
        currentBlock++;
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
        debugPrint('🔵 Focus resumed');
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
      debugPrint('⏸️ Session paused');
    } else if (nextStatus == 'running') {
      await _handleLightAndResume();
    }
  }

  // ========================================================================
  // QUIT SESSION HANDLER - FIXED
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
          belowMinimum 
              ? 'You\'ve only focused for $actualFocusDurationMinutes minutes. Sessions under $minimumSessionMinutes minutes won\'t be saved.\n\nAre you sure you want to quit?'
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
            child: Text('Continue Session', style: TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              _timer?.cancel();

              try {
                pulseController.dispose();
              } catch (_) {}

              if (_rikazConnected && _lightInitialized) {
                await _debouncedLightOff();
              }

              Navigator.pop(dialogContext);

              // CRITICAL FIX: Do NOT set _completionHandled here
              // Let _endSessionInDB handle it AFTER showing the progress dialog
              await _endSessionInDB(completed: false);

              if (mounted && !_isNavigatingAway) {
                _isNavigatingAway = true;
                Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false);
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

    if (_rikazConnected && _lightInitialized && !_completionHandled) {
      _debouncedLightOff();
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
    return focusBgColor;
  }

  Color get ringColor {
    if (status == 'paused') return pausedBgColor.withOpacity(0.6);
    if (mode == 'break') return const Color.fromARGB(255, 255, 169, 8);
    return accentThemeColor;
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
          Container(color: backgroundColor),
          
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

          SafeArea(
            child: Column(
              children: [
                Column(
                  children: [
                    SizedBox(height: screenHeight * 0.05),

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

                    Stack(
                      alignment: Alignment.center,
                      children: [
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(formatTime(timeLeft), style: TextStyle(
                              fontSize: screenWidth * 0.13,
                              fontWeight: FontWeight.w600,
                              color: primaryTextDark,
                              letterSpacing: 2,
                            )),
                            SizedBox(height: screenHeight * 0.01),
                            if (isPomodoro && !isBreak)
                              Text('$currentBlock/$totalBlocks Sessions',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                ))
                            else if (isBreak)
                              Text('Take a rest',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                ))
                            else
                              Text('Stay focused',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.036,
                                  color: secondaryTextGrey,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    Container(
                      decoration: BoxDecoration(
                        color: isPaused ? pausedBgColor : accentThemeColor,
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
                                Icon(isPaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white, size: screenWidth * 0.06),
                                SizedBox(width: screenWidth * 0.02),
                                Text(isPaused ? 'Resume' : 'Pause',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.04,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.02),

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
                                Icon(Icons.close, color: Colors.white, size: screenWidth * 0.05),
                                SizedBox(width: screenWidth * 0.015),
                                Text('End Session', style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),

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
  final String id, name, iconName, colorHex;
  final String? filePathUrl;

  SoundOption({
    required this.id,
    required this.name,
    required this.filePathUrl,
    required this.iconName,
    required this.colorHex,
  });

  factory SoundOption.off() => SoundOption(
    id: 'off', name: 'No Sound', filePathUrl: null,
    iconName: 'volume_off_rounded', colorHex: '#64748B',
  );

  IconData get icon {
    const iconMap = {
      'water_drop_outlined': Icons.water_drop_outlined,
      'water_rounded': Icons.water_rounded,
      'waves_rounded': Icons.waves_rounded,
    };
    return iconMap[iconName] ?? Icons.volume_off_rounded;
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
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasAutoPlayed) {
          _autoPlayPreselectedSound();
        }
      });
    } else {
      _currentSound = SoundOption.off();
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
      debugPrint('🎵 AUTO-PLAY: ${_currentSound.name}');
    } catch (e) {
      debugPrint('❌ Error auto-playing: $e');
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

      if (_currentSound.id != 'off') {
        final matchingSound = fetchedSounds.firstWhere(
          (s) => s.id == _currentSound.id,
          orElse: () => _currentSound,
        );
        if (mounted && matchingSound.id == _currentSound.id) {
          setState(() => _currentSound = matchingSound);
        }
      }

      return fetchedSounds;
    } catch (e) {
      debugPrint('❌ Error fetching sounds: $e');
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
        debugPrint('Error playing: $e');
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
      if (mounted) setState(() => _isSoundPlaying = false);
    } else {
      await _audioPlayer.resume();
      if (mounted) setState(() => _isSoundPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final displayIcon = _currentSound.id != 'off' ? _currentSound.icon : Icons.volume_off_rounded;
    final displayColor = _currentSound.id != 'off' ? _currentSound.color : secondaryTextGrey;
    final String displayText = _currentSound.id != 'off' && _currentSound.name.isNotEmpty
        ? _currentSound.name
        : 'Background Sound';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (!mounted) return;
            setState(() => _isExpanded = !_isExpanded);
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
                child: Icon(displayIcon, color: displayColor, size: screenWidth * 0.045),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Text(displayText, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryTextDark,
                  fontSize: screenWidth * 0.04,
                )),
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
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Divider(height: 1, color: secondaryTextGrey.withOpacity(0.2)),
              FutureBuilder<List<SoundOption>>(
                future: _soundsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Center(child: CircularProgressIndicator(color: accentThemeColor)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Center(child: Text('Could not load sounds', style: TextStyle(color: secondaryTextGrey))),
                    );
                  }
                  final sounds = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sounds.length,
                    itemBuilder: (context, index) {
                      final sound = sounds[index];
                      final isSelected = sound.id == _currentSound.id && _isSoundPlaying;
                      return _SoundRow(
                        sound: sound,
                        isSelected: isSelected,
                        onTap: () => _onSoundSelected(sound),
                      );
                    },
                  );
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

  const _SoundRow({required this.sound, required this.isSelected, required this.onTap});

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
              child: Icon(sound.icon, color: sound.color, size: screenWidth * 0.045),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(sound.name, style: TextStyle(
                fontWeight: FontWeight.w500,
                color: primaryTextDark,
                fontSize: screenWidth * 0.037,
              )),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentThemeColor, size: screenWidth * 0.05),
          ],
        ),
      ),
    );
  }
}