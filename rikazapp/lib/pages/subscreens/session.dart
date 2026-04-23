// Session.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:rikazapp/services/rikaz_light_service.dart';
import 'package:rikazapp/main.dart';
import 'package:rikazapp/pages/mainscreens/games/games.dart';

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

class SessionPage extends StatefulWidget {
  final String sessionType;
  final String duration;
  final String? numberOfBlocks;

  // Camera / detection settings
  final bool? isCameraDetectionEnabled;
  final double? sensitivity;
  final String? notificationStyle;

  // NEW TRIGGERS & ALERT SETTINGS
  final String? subtleAlertType; 
  final bool? sleepTrigger;
  final bool? presenceTrigger;
  final bool? phoneTrigger;      
  final String? notificationSoundUrl;

  // Hardware + sound
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
    this.subtleAlertType,
    this.sleepTrigger,
    this.presenceTrigger,
    this.phoneTrigger,          
    this.notificationSoundUrl,
    this.rikazConnected,
    this.selectedSoundId,
    this.selectedSoundName,
    this.selectedSoundUrl,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with SingleTickerProviderStateMixin {
  bool _rikazConnected = false;
  bool _lightInitialized = false;

  late bool isPomodoro;
  late int focusMinutes;
  late int breakMinutes;
  late int totalBlocks;

  String? _currentSessionId;
  DateTime? _sessionStartTime; 
  int _totalFocusSeconds = 0;
  int _sessionDistractionCount = 0; 

  String mode = 'focus';
  String status = 'running';
  int currentBlock = 1;
  int timeLeft = 0;
  List<int> completedBlocks = [];

  Timer? _timer;
  late AnimationController pulseController;

  Timer? _connectionCheckTimer;
  bool _completionHandled = false;

  DateTime? _lastLightOffTime;
  static const Duration _lightDebounceDelay = Duration(seconds: 2);
  static const int minimumSessionMinutes = 10;

  final AudioPlayer _alertPlayer = AudioPlayer();
  bool _isAlertPlaying = false;

  // ============================================================================
  // MODERN UI DIALOG FLOW
  // ============================================================================

  Future<String?> _showProgressLevelDialog() async {
    String? selected;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.track_changes_rounded, size: 50, color: dfTealCyan),
              const SizedBox(height: 16),
              const Text(
                "How much of your goal did you achieve in this session?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dfNavyIndigo),
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                title: "Fully",
                subtitle: "I accomplished everything I set out to do",
                icon: Icons.check_circle,
                color: Colors.green,
                onTap: () {
                  selected = 'fully';
                  Navigator.pop(context);
                },
              ),
              _buildOptionCard(
                title: "Partially",
                subtitle: "I made good progress but didn't finish",
                icon: Icons.trending_up,
                color: Colors.orange,
                onTap: () {
                  selected = 'partially';
                  Navigator.pop(context);
                },
              ),
              _buildOptionCard(
                title: "Barely",
                subtitle: "I struggled to stay focused",
                icon: Icons.sentiment_dissatisfied,
                color: Colors.redAccent,
                onTap: () {
                  selected = 'barely';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  Future<String> _showDistractionDialog() async {
    String selected = 'low';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_outlined, size: 50, color: dfTealCyan),
              const SizedBox(height: 16),
              const Text(
                "How distracted were you approximately?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dfNavyIndigo),
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                title: "Low",
                subtitle: "I was highly focused",
                icon: Icons.battery_full,
                color: dfTealCyan,
                onTap: () {
                  selected = 'low';
                  Navigator.pop(context);
                },
              ),
              _buildOptionCard(
                title: "Medium",
                subtitle: "A few interruptions happened",
                icon: Icons.battery_charging_full,
                color: Colors.blueGrey,
                onTap: () {
                  selected = 'medium';
                  Navigator.pop(context);
                },
              ),
              _buildOptionCard(
                title: "High",
                subtitle: "I found it hard to ignore distractions",
                icon: Icons.battery_alert,
                color: Colors.redAccent,
                onTap: () {
                  selected = 'high';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  Future<void> _showSummaryDialog(String distraction, String progress) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Session Summary",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dfNavyIndigo),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: primaryBackground, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRowUI(Icons.timer_outlined, 'Total Time', '${(_totalFocusSeconds ~/ 60)} min'),
                    const Divider(height: 20),
                    _summaryRowUI(Icons.auto_graph, 'Progress', progress.toUpperCase()),
                    const Divider(height: 20),
                    _summaryRowUI(Icons.notifications_off_outlined, 'Distraction', distraction.toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dfTealCyan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showMotivationalPopup(String distraction, String progress) {
  String message = "";
  
  // ============================================================================
  // SMART MOTIVATIONAL MESSAGES BASED ON PROGRESS + DISTRACTION
  // ============================================================================
  
  // FULLY + LOW
  if (progress == 'fully' && distraction == 'low') {
    message = "Outstanding! You maintained excellent focus and completed everything. This is peak performance! 🌟";
  }
  // FULLY + MEDIUM
  else if (progress == 'fully' && distraction == 'medium') {
    message = "Great job! You pushed through the distractions and finished strong. That's real determination! 💪";
  }
  // FULLY + HIGH
  else if (progress == 'fully' && distraction == 'high') {
    message = "Incredible resilience! Despite heavy distractions, you completed your goals. Next time will be even better! 🔥";
  }
  
  // PARTIALLY + LOW
  else if (progress == 'partially' && distraction == 'low') {
    message = "Good focus quality! You stayed concentrated even though you didn't finish. Keep building on this momentum! 📈";
  }
  // PARTIALLY + MEDIUM
  else if (progress == 'partially' && distraction == 'medium') {
    message = "Nice effort! You made solid progress despite some interruptions. You're on the right path! ✨";
  }
  // PARTIALLY + HIGH
  else if (progress == 'partially' && distraction == 'high') {
    message = "You tried your best in a challenging environment. Every small step counts. Tomorrow is a fresh start! 🌱";
  }
  
  // BARELY + LOW
  else if (progress == 'barely' && distraction == 'low') {
    message = "It happens! Even with focus, sometimes tasks are tough. Don't be discouraged—you'll bounce back! 🔄";
  }
  // BARELY + MEDIUM
  else if (progress == 'barely' && distraction == 'medium') {
    message = "Challenging session, but you showed up! That's what matters. Identify what distracted you and try again! 💫";
  }
  // BARELY + HIGH
  else if (progress == 'barely' && distraction == 'high') {
    message = "This was a tough one with many interruptions. Learn from it and create a better setup next time. You've got this! 🌟";
  }
  
  // DEFAULT (في حال قيمة غريبة)
  else {
    message = "Every session is a learning experience. Reflect and improve for next time. Keep going! 🚀";
  }
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 80, color: dfTealCyan),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dfNavyIndigo),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dfNavyIndigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false),
                child: const Text(
                  'Finish',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    ),
  );
}

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dfNavyIndigo)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: secondaryTextGrey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: secondaryTextGrey),
          ],
        ),
      ),
    );
  }

  Widget _summaryRowUI(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: dfTealCyan),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: secondaryTextGrey)),
          ],
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: dfNavyIndigo)),
      ],
    );
  }

  // ============================================================================
  // DATABASE & TIMER LOGIC
  // ============================================================================

  void onPhaseEnd() async {
    if (!mounted || _completionHandled) return;

    if (!isPomodoro || (mode == 'focus' && currentBlock >= totalBlocks)) {
      _timer?.cancel();
      setState(() => status = 'idle');

      if (_rikazConnected) {
        await RikazLightService.sendCommand(jsonEncode({'sessionComplete': 'true'}));
        await _debouncedLightOff();
      }

      String? p = await _showProgressLevelDialog();
      String d = await _showDistractionDialog();

      _endSessionInDB(progress: p, distraction: d);

      if (mounted) {
        await _showSummaryDialog(d, p ?? 'partially');
        _showMotivationalPopup(d, p ?? 'partially');
      }
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
      if (_rikazConnected) await RikazLightService.setBreakLight();
    } else {
      setState(() {
        currentBlock++;
        mode = 'focus';
        timeLeft = focusMinutes * 60;
      });
      if (_rikazConnected) await RikazLightService.setFocusLight();
    }
    startTimer();
  }

  Future<void> _endSessionInDB({String? progress, String? distraction}) async {
    if (_completionHandled) return;
    final supabase = Supabase.instance.client;
    if (_currentSessionId == null) return;

    final actual = (_totalFocusSeconds ~/ 60);

    if (actual < minimumSessionMinutes) {
      _completionHandled = true;
      try {
        await supabase.from('Focus_Session').delete().eq('session_id', _currentSessionId!);
      } catch (_) {}
      return;
    }

    _completionHandled = true;
    try {
      await supabase.from('Focus_Session').update({
        'end_time': DateTime.now().toIso8601String(),
        'actual_duration': actual,
        'progress_level': progress,
        'distraction_level': distraction,
        'distraction_count': _sessionDistractionCount, 
      }).eq('session_id', _currentSessionId!);
    } catch (e) {
      debugPrint('DB Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    isPomodoro = widget.sessionType == 'pomodoro';
    if (isPomodoro) {
      focusMinutes = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 25;
      breakMinutes = (focusMinutes == 25) ? 5 : 10;
      totalBlocks = int.tryParse(widget.numberOfBlocks ?? '4') ?? 4;
    } else {
      focusMinutes = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
      breakMinutes = 0;
      totalBlocks = 1;
    }

    timeLeft = focusMinutes * 60;
    _rikazConnected = widget.rikazConnected ?? false;

    _alertPlayer.setReleaseMode(ReleaseMode.loop);
    _setupDistractionListener();

    startTimer();
    _startSessionInDB();

    if (_rikazConnected) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted || status != 'running') return;

        final ok = await RikazLightService.setFocusLight();
        if (ok) {
          _lightInitialized = true;
          _startConnectionMonitoring();
          _sendTimerUpdateToESP32();
        } else {
          _handleLightCommandFailure();
        }
      });
    }

    pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  // ============================================================================
  // DISTRACTION AUDIO LOGIC (STRICT SUPABASE ONLY)
  // ============================================================================
  void _setupDistractionListener() {
    RikazLightService.onDistractionDetected = (count) {
      if (!mounted) return;
      
      setState(() {
        _sessionDistractionCount = count;
      });

      _triggerAudioAlert();
    };
  }

  Future<void> _triggerAudioAlert() async {
    bool shouldPlaySound = widget.notificationStyle == 'strong' ||
        (widget.notificationStyle == 'subtle' && widget.subtleAlertType == 'sound');

    if (shouldPlaySound) {
      try {
        await _alertPlayer.stop(); 
        await _alertPlayer.setVolume(1.0); 
        
        String finalUrl = widget.notificationSoundUrl ?? 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/notify.mp3';
        
        await _alertPlayer.play(UrlSource(finalUrl));
        
        Future.delayed(const Duration(seconds: 4), () async {
          if (mounted) await _alertPlayer.stop();
        });
      } catch (e) {
        debugPrint('❌ Error playing alert sound: $e');
        try {
          await _alertPlayer.play(UrlSource('https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/notify.mp3'));
          Future.delayed(const Duration(seconds: 4), () async {
            if (mounted) await _alertPlayer.stop();
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _startSessionInDB() async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final res = await supabase
          .from('Focus_Session')
          .insert({
            'user_id': uid,
            'session_type': widget.sessionType,
            'start_time': DateTime.now().toIso8601String(),
            'planned_duration': isPomodoro ? (focusMinutes * totalBlocks) : focusMinutes,
            'camera_monitored': widget.isCameraDetectionEnabled ?? false,
          })
          .select('session_id');

      if (res.isNotEmpty) {
        setState(() => _currentSessionId = res.first['session_id'].toString());
      }
    } catch (_) {}
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status != 'running') return;
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
          if (mode == 'focus') _totalFocusSeconds++;
        }
      });

      _sendTimerUpdateToESP32();

      if (timeLeft <= 0) onPhaseEnd();
    });
  }

  void onPauseResume() async {
    if (!mounted) return;

    if (status == 'paused') {
      setState(() => status = 'running');
      pulseController.repeat(reverse: true);
      _sendTimerUpdateToESP32();
    } else {
      setState(() => status = 'paused');
      pulseController.stop();
      _sendTimerUpdateToESP32();
    }
  }

  void onQuit() {
    final prev = status;
    setState(() => status = 'paused');
    pulseController.stop();
    _sendTimerUpdateToESP32();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              setState(() => status = prev);
              if (prev == 'running') pulseController.repeat(reverse: true);
              _sendTimerUpdateToESP32();
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              _timer?.cancel();
              if (_rikazConnected) await _debouncedLightOff();

              Navigator.pop(ctx);
              await _endSessionInDB(progress: 'none', distraction: 'high');

              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/tabs', (r) => false);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToBreakActivities() async {
    _timer?.cancel();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamesScreen(breakSecondsRemaining: timeLeft),
      ),
    );

    if (!mounted) return;

    if (result is int) setState(() => timeLeft = result);

    if (timeLeft <= 0 && mode == 'break') {
      onPhaseEnd();
    } else {
      startTimer();
    }
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !RikazConnectionState.isConnected) {
        timer.cancel();
        return;
      }

      if (!await RikazLightService.isConnected()) {
        timer.cancel();
        await RikazLightService.disconnect();
        RikazConnectionState.isConnected = false;

        if (mounted) {
          setState(() {
            _rikazConnected = false;
            _lightInitialized = false;
          });
        }

        _handleLightCommandFailure();
      }
    });
  }

  void _handleLightCommandFailure() {
    if (!mounted) return;
    if (status == 'running') {
      setState(() => status = 'paused');
      pulseController.stop();
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection lost.')));
  }

  Future<void> _debouncedLightOff() async {
    if (!_rikazConnected || !_lightInitialized) return;

    final now = DateTime.now();
    if (_lastLightOffTime != null && now.difference(_lastLightOffTime!) < _lightDebounceDelay) return;
    _lastLightOffTime = now;

    try {
      await RikazLightService.sendCommand(jsonEncode({"on":false}));
    } catch (_) {}
  }

  Future<void> _sendTimerUpdateToESP32() async {
    if (!_rikazConnected || !_lightInitialized) return;

    try {
      final cmd = jsonEncode({
        'timer': {
          'minutes': timeLeft ~/ 60,
          'seconds': timeLeft % 60,
          'status': status,
          'mode': mode,
        },
        'config': {
          'style': widget.notificationStyle ?? 'strong',
          'subtleType': widget.subtleAlertType ?? 'light',
        }
      });
      await RikazLightService.sendCommand(cmd);
    } catch (_) {}
  }

  Future<void> _sendMotivationalMessage() async {
    if (!_rikazConnected || !_lightInitialized) return;
    try {
      await RikazLightService.sendCommand(jsonEncode({'motivation': 'show'}));
    } catch (_) {}
  }

  String formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  double get progressValue => (1 - (timeLeft / max(focusMinutes * 60, 1))).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isPaused = status == 'paused';
    final timerDiameter = screenWidth * 0.75;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: isPaused ? pausedBgColor : (mode == 'break' ? breakBgColor : focusBgColor)),
          Positioned(
            top: screenHeight * 0.38,
            left: -screenWidth * 0.5,
            right: -screenWidth * 0.5,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(screenWidth * 1.5)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.05),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    isPomodoro
                        ? (mode == 'break' ? 'Break' : 'Block $currentBlock/$totalBlocks')
                        : 'Focus Session',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: timerDiameter,
                      height: timerDiameter,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30)],
                      ),
                    ),
                    SizedBox(
                      width: timerDiameter * 0.92,
                      height: timerDiameter * 0.92,
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: progressValue,
                          color: isPaused ? pausedBgColor : (mode == 'break' ? Colors.orange : accentThemeColor),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatTime(timeLeft),
                          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: primaryTextDark),
                        ),
                        Text(mode == 'break' ? 'Take a rest' : 'Stay focused', style: const TextStyle(color: secondaryTextGrey)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.04),
                if (mode == 'break') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dfDeepTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: _navigateToBreakActivities,
                    icon: const Icon(Icons.videogame_asset_outlined),
                    label: const Text('Play Activity'),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused ? pausedBgColor : accentThemeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: onPauseResume,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorIndicatorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: onQuit,
                  icon: const Icon(Icons.close),
                  label: const Text('End Session'),
                ),
                
                // COMPACT SOUND SECTION AT THE BOTTOM
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SoundSection(
                      preselectedSoundId: widget.selectedSoundId,
                      preselectedSoundUrl: widget.selectedSoundUrl,
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

  @override
  void dispose() {
    _timer?.cancel();
    _connectionCheckTimer?.cancel();
    pulseController.dispose();
    
    _alertPlayer.stop();
    _alertPlayer.dispose();
    
    super.dispose();
  }
}

// ============================================================================
// COMPACT SOUND CONTROL SECTION
// ============================================================================
class SoundSection extends StatefulWidget {
  final String? preselectedSoundId;
  final String? preselectedSoundUrl;

  const SoundSection({
    super.key,
    this.preselectedSoundId,
    this.preselectedSoundUrl,
  });

  @override
  State<SoundSection> createState() => _SoundSectionState();
}

class _SoundSectionState extends State<SoundSection> {
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  late Future<List<SoundOption>> _soundsFuture;

  late SoundOption _currentSound;
  bool _isSoundPlaying = false;

  @override
  void initState() {
    super.initState();

    _bgAudioPlayer.setReleaseMode(ReleaseMode.loop);

    if (widget.preselectedSoundId != null &&
        widget.preselectedSoundId != 'off' &&
        widget.preselectedSoundUrl != null) {
      _currentSound = SoundOption(
        id: widget.preselectedSoundId!,
        name: widget.preselectedSoundId!,
        filePathUrl: widget.preselectedSoundUrl,
        iconName: 'music_note_rounded',
        colorHex: '#287C85',
      );
      _isSoundPlaying = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _bgAudioPlayer.stop();
          await _bgAudioPlayer.play(UrlSource(widget.preselectedSoundUrl!));
        } catch (_) {}
      });
    } else {
      _currentSound = SoundOption.off();
    }

    _soundsFuture = _fetchSounds();
  }

  Future<List<SoundOption>> _fetchSounds() async {
    final List<SoundOption> supabaseFallbacks = [
      SoundOption.off(),
      SoundOption(
        id: 'Rain', name: 'Rain', 
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3', 
        iconName: 'water_drop_outlined', colorHex: '#5DADE2'
      ),
      SoundOption(
        id: 'River', name: 'River', 
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3', 
        iconName: 'waves_rounded', colorHex: '#4FC3F7'
      ),
      SoundOption(
        id: 'White Noise', name: 'White Noise', 
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3', 
        iconName: 'waves_rounded', colorHex: '#BA9CF1'
      ),
    ];

    try {
      final res = await Supabase.instance.client.from('Sound_Option').select();
      if (res.isEmpty) return supabaseFallbacks;

      final list = <SoundOption>[
        SoundOption.off(),
        ...res.map((i) => SoundOption(
              id: i['sound_name'],
              name: i['sound_name'],
              filePathUrl: i['sound_file_path'],
              iconName: i['icon_name'],
              colorHex: i['color_hex'],
            )),
      ];

      final matchId = widget.preselectedSoundId;
      if (matchId != null && matchId != 'off') {
        final match = list.where((s) => s.id == matchId).toList();
        if (match.isNotEmpty && mounted) {
          setState(() => _currentSound = match.first);
        }
      }

      return list;
    } catch (_) {
      return supabaseFallbacks;
    }
  }

  Future<void> _playSelectedSound(SoundOption sound) async {
    try {
      await _bgAudioPlayer.stop();
      if (sound.id == 'off' || sound.filePathUrl == null) {
        if (mounted) setState(() => _isSoundPlaying = false);
        return;
      }
      
      await _bgAudioPlayer.play(UrlSource(sound.filePathUrl!));
      if (mounted) setState(() => _isSoundPlaying = true);
    } catch (e) {
      debugPrint('X Error playing selected sound: $e');
      
      String fallbackUrl = sound.filePathUrl!;
      if (sound.name == 'Rain' || sound.name == 'River') fallbackUrl = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3';
      else if (sound.name == 'White Noise') fallbackUrl = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3';
      
      try {
        await _bgAudioPlayer.play(UrlSource(fallbackUrl));
        if (mounted) setState(() => _isSoundPlaying = true);
      } catch (_) {}
    }
  }

  Future<void> _togglePlayPause() async {
    if (_currentSound.id == 'off' || _currentSound.filePathUrl == null) return;
    try {
      if (_isSoundPlaying) {
        await _bgAudioPlayer.pause();
        if (mounted) setState(() => _isSoundPlaying = false);
      } else {
        await _bgAudioPlayer.play(UrlSource(_currentSound.filePathUrl!));
        if (mounted) setState(() => _isSoundPlaying = true);
      }
    } catch (_) {
      _playSelectedSound(_currentSound); // Trigger fallback attempt
    }
  }

  @override
  void dispose() {
    _bgAudioPlayer.stop();
    _bgAudioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _currentSound.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_currentSound.icon, color: _currentSound.color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FutureBuilder<List<SoundOption>>(
            future: _soundsFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: dfTealCyan));
              final sounds = snap.data!;
              
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentSound.id,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: dfTealCyan),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dfNavyIndigo),
                  onChanged: (String? newId) {
                    if (newId != null) {
                      final newSound = sounds.firstWhere((s) => s.id == newId, orElse: () => SoundOption.off());
                      setState(() => _currentSound = newSound);
                      _playSelectedSound(newSound);
                    }
                  },
                  items: sounds.map((s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name),
                  )).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            _isSoundPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: _currentSound.id == 'off' ? secondaryTextGrey.withOpacity(0.5) : dfTealCyan,
            size: 40,
          ),
          onPressed: _currentSound.id == 'off' ? null : _togglePlayPause,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class SoundOption {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final String? filePathUrl;

  SoundOption({
    required this.id,
    required this.name,
    required this.filePathUrl,
    required this.iconName,
    required this.colorHex,
  });

  factory SoundOption.off() => SoundOption(
        id: 'off',
        name: 'No Sound',
        filePathUrl: null,
        iconName: 'volume_off_rounded',
        colorHex: '#64748B',
      );

  IconData get icon {
    const m = {
      'water_drop_outlined': Icons.water_drop_outlined,
      'water_rounded': Icons.water_rounded,
      'waves_rounded': Icons.waves_rounded,
      'volume_off_rounded': Icons.volume_off_rounded,
      'music_note_rounded': Icons.music_note_rounded,
    };
    return m[iconName] ?? Icons.music_note_rounded;
  }

  Color get color {
    final h = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}