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
// MINIMALIST & ALIVE THEME COLORS
// ============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);
const Color breakColor = Color(0xFFF4A261);
const Color pausedColor = Color(0xFF9E9E9E);

List<BoxShadow> get subtleShadow => [
      BoxShadow(
          color: dfNavyIndigo.withOpacity(0.04),
          blurRadius: 30,
          offset: const Offset(0, 10)),
    ];

class SessionPage extends StatefulWidget {
  final String sessionType;
  final String duration;
  final String? numberOfBlocks;

  final bool? isCameraDetectionEnabled;
  final double? sensitivity;
  final String? notificationStyle;

  final String? subtleAlertType;
  final bool? sleepTrigger;
  final bool? presenceTrigger;
  final bool? phoneTrigger;
  final String? notificationSoundUrl;

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

class _SessionPageState extends State<SessionPage>
    with TickerProviderStateMixin {
  bool _rikazConnected = false;
  bool _lightInitialized = false;

  late bool isPomodoro;
  late int focusMinutes;
  late int breakMinutes;
  late int totalBlocks;
  late bool isDemo;

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  int _totalFocusSeconds = 0;
  int _sessionDistractionCount = 0;

  // true = timer reached zero naturally → 'completed'
  // false = user pressed End → 'cancelled'
  bool _sessionCompleted = false;

  String mode = 'focus';
  String status = 'running';
  int currentBlock = 1;
  int timeLeft = 0;
  List<int> completedBlocks = [];

  Timer? _timer;
  Timer? _connectionCheckTimer;
  bool _completionHandled = false;
final ValueNotifier<int> _breakTimerNotifier = ValueNotifier<int>(0);
bool _breakActivityOpen = false;
  DateTime? _lastLightOffTime;
  static const Duration _lightDebounceDelay = Duration(seconds: 2);
  static const int minimumSessionMinutes = 10;

  final AudioPlayer _alertPlayer = AudioPlayer();

  late AnimationController pulseController;
  late Animation<double> pulseAnimation;
  late Animation<double> bgShiftAnimation;

  // ============================================================================
  // INIT & DISPOSE
  // ============================================================================

  @override
  void initState() {
    super.initState();

 isPomodoro = widget.sessionType == 'pomodoro';
    
    // Parse the minutes first to detect if it's a demo
    focusMinutes = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 25;
    
    // If the duration is exactly 1 minute, we treat it as a Demo
    isDemo = focusMinutes == 1;

    if (isPomodoro) {
      if (isDemo) {
        breakMinutes = 1; // Give a 1-minute break for demo purposes
      } else {
        breakMinutes = (focusMinutes == 25) ? 5 : 10;
      }
      totalBlocks = int.tryParse(widget.numberOfBlocks ?? '4') ?? 4; 
    } else {
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

    pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat(reverse: true);
    pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOutSine));
    bgShiftAnimation = Tween<double>(begin: -0.5, end: 0.5).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectionCheckTimer?.cancel();
    _breakTimerNotifier.dispose();
    pulseController.dispose();
    _alertPlayer.stop();
    _alertPlayer.dispose();
    super.dispose();
    
  }

  // ============================================================================
  // DISTRACTION LISTENER
  // ============================================================================

  void _setupDistractionListener() {
    RikazLightService.onDistractionDetected = (count) {
      if (!mounted) return;
      setState(() => _sessionDistractionCount = count);
      _triggerAudioAlert();
    };

    RikazLightService.onDistractionEvent = (String type, int duration) {
      if (!mounted) return;
      _insertDistractionEvent(type, duration);
    };
  }

  Future<void> _triggerAudioAlert() async {
    bool shouldPlaySound = widget.notificationStyle == 'strong' ||
        (widget.notificationStyle == 'subtle' &&
            widget.subtleAlertType == 'sound');

    if (shouldPlaySound) {
      try {
        await _alertPlayer.stop();
        await _alertPlayer.setVolume(1.0);
        String finalUrl = widget.notificationSoundUrl ??
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/notify.mp3';
        await _alertPlayer.play(UrlSource(finalUrl));
        Future.delayed(const Duration(seconds: 4), () async {
          if (mounted) await _alertPlayer.stop();
        });
      } catch (e) {
        try {
          await _alertPlayer.play(UrlSource(
              'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/notify.mp3'));
          Future.delayed(const Duration(seconds: 4), () async {
            if (mounted) await _alertPlayer.stop();
          });
        } catch (_) {}
      }
    }
  }

  // ============================================================================
  // DATABASE — START
  // ============================================================================

  Future<void> _startSessionInDB() async {
    if (isDemo) return;
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _sessionStartTime = DateTime.now();

    String? pomodoroType;
    if (isPomodoro) {
      pomodoroType = focusMinutes == 25 ? '25-5' : '50-10';
    }

    try {
      final res = await supabase
          .from('Focus_Session')
          .insert({
            'user_id': uid,
            'session_type': widget.sessionType,
            'start_time': _sessionStartTime!.toIso8601String(),
            'planned_duration':
                isPomodoro ? (focusMinutes * totalBlocks) : focusMinutes,
            'camera_monitored': widget.isCameraDetectionEnabled ?? false,
            'session_status': 'active',
            'pomodoro_type': pomodoroType,
          })
          .select('session_id');

      if (res.isNotEmpty) {
        final sid = res.first['session_id'] as int;
        setState(() => _currentSessionId = sid.toString());

        await supabase.from('Session_Distraction').insert([
          {
            'session_id': sid,
            'distraction_type': 'phone_use',
            'distraction_count': 0,
            'total_duration_seconds': 0,
          },
          {
            'session_id': sid,
            'distraction_type': 'sleeping',
            'distraction_count': 0,
            'total_duration_seconds': 0,
          },
          {
            'session_id': sid,
            'distraction_type': 'absence',
            'distraction_count': 0,
            'total_duration_seconds': 0,
          },
        ]);

        debugPrint('✅ Session + 3 distraction rows created: $sid');
      }
    } catch (e) {
      debugPrint('❌ _startSessionInDB error: $e');
    }
  }

  // ============================================================================
  // DATABASE — DISTRACTION EVENT
  // ============================================================================

  Future<void> _insertDistractionEvent(
      String type, int durationSeconds) async {
        if (isDemo) return;
    debugPrint(
        '_insertDistractionEvent — sessionId: $_currentSessionId, type: $type, duration: $durationSeconds');
    if (_currentSessionId == null) {
      debugPrint('SKIPPED — _currentSessionId is null');
      return;
    }

    final sid = int.parse(_currentSessionId!);
    try {
      final existing = await Supabase.instance.client
          .from('Session_Distraction')
          .select('distraction_count, total_duration_seconds')
          .eq('session_id', sid)
          .eq('distraction_type', type)
          .single();

      await Supabase.instance.client
          .from('Session_Distraction')
          .update({
            'distraction_count': (existing['distraction_count'] as int) + 1,
            'total_duration_seconds':
                (existing['total_duration_seconds'] as int) + durationSeconds,
          })
          .eq('session_id', sid)
          .eq('distraction_type', type);

      debugPrint('✅ Session_Distraction updated: $type +1, +${durationSeconds}s');
    } catch (e) {
      debugPrint('❌ Session_Distraction error: $e');
    }
  }

  // ============================================================================
  // DATABASE — END
  // ============================================================================

  Future<void> _endSessionInDB({
    String? progress,
    String? distraction,
    String? overrideStatus,
  }) async {
    if (_completionHandled) return;
    if (isDemo) {
      _completionHandled = true;
      return; 
    }

    final supabase = Supabase.instance.client;
    if (_currentSessionId == null) return;

    final int actual = _totalFocusSeconds ~/ 60;

    if (actual < minimumSessionMinutes) {
      _completionHandled = true;
      try {
        await supabase
            .from('Focus_Session')
            .delete()
            .eq('session_id', _currentSessionId!);
        debugPrint('🗑️ Session deleted (< $minimumSessionMinutes min)');
      } catch (e) {
        debugPrint('❌ DB Delete Error: $e');
      }
      return;
    }

    _completionHandled = true;

    final String finalStatus = overrideStatus ??
        (_sessionCompleted ? 'completed' : 'cancelled');

    try {
      await supabase.from('Focus_Session').update({
        'end_time': DateTime.now().toIso8601String(),
        'actual_duration': actual,
        'progress_level': progress,
        'distraction_level': distraction,
        'distraction_count': _sessionDistractionCount,
        'session_status': finalStatus,
        'pomodoro_type': isPomodoro
            ? (focusMinutes == 25 ? '25-5' : '50-10')
            : null,
      }).eq('session_id', _currentSessionId!);
      debugPrint('✅ Session saved: $finalStatus | ${actual}min');
    } catch (e) {
      debugPrint('❌ DB Update Error: $e');
    }
  }

  // ============================================================================
  // AUTO DISTRACTION CALC FOR CAMERA
  // كاميرا شغّالة: يحسب الـ distraction تلقائياً من عدد مرات التشتت
  // ============================================================================

  String _calculateDistractionLevel() {
    final double minutes = _totalFocusSeconds / 60.0;
    final double rate =
        minutes < 0.1 ? 0.0 : (_sessionDistractionCount / minutes) * 10.0;
    if (rate < 1.0) return 'low';
    if (rate < 2.0) return 'medium';
    return 'high';
  }

  // ============================================================================
  // TIMER
  // ============================================================================

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

    if (mode == 'focus') {
      _totalFocusSeconds++;
    }
  }
});

if (mode == 'break') {
  _breakTimerNotifier.value = timeLeft;
}

      _sendTimerUpdateToESP32();
      if (timeLeft <= 0) onPhaseEnd();
    });
  }

  // ============================================================================
  // PHASE END
  // ============================================================================

  void onPhaseEnd() async {
    if (!mounted || _completionHandled) return;

    if (!isPomodoro || (mode == 'focus' && currentBlock >= totalBlocks)) {
      _timer?.cancel();
      setState(() => status = 'idle');

      if (_rikazConnected) {
        await RikazLightService.sendCommand(
            jsonEncode({'sessionComplete': 'true'}));
        await _debouncedLightOff();
      }

      _sessionCompleted = true;

      final bool cameraOn = widget.isCameraDetectionEnabled ?? false;

      String? p;
      String d;

      if (cameraOn) {
        // كاميرا شغّالة: يسأل عن البروقرس يدوياً، يحسب الديستراكشن تلقائياً
        p = await _showProgressLevelDialog();
        d = _calculateDistractionLevel();
      } else {
        // كاميرا مطفية: يسأل عن كليهما يدوياً
        p = await _showProgressLevelDialog();
        d = await _showDistractionDialog();
      }

      await _endSessionInDB(progress: p, distraction: d);

      if (mounted) {
        await _showSummaryDialog(d, p ?? 'partially',
            cameraCalculated: cameraOn);
        _showMotivationalPopup(d, p ?? 'partially');
      }
      return;
    }

    // Pomodoro: switch focus ↔ break
    if (mode == 'focus') {
      if (!completedBlocks.contains(currentBlock)) {
        completedBlocks.add(currentBlock);
        _sendMotivationalMessage();
      }
setState(() {
  mode = 'break';
  timeLeft = breakMinutes * 60;
  _breakTimerNotifier.value = timeLeft;
});
      if (_rikazConnected) await RikazLightService.setBreakLight();
    } else {
  if (_breakActivityOpen && Navigator.of(context).canPop()) {
    Navigator.of(context).pop(0);
    _breakActivityOpen = false;
  }

  setState(() {
    currentBlock++;
    mode = 'focus';
    timeLeft = focusMinutes * 60;
    _breakTimerNotifier.value = 0;
  });

  if (_rikazConnected) await RikazLightService.setFocusLight();
}
    startTimer();
  }

  // ============================================================================
  // PAUSE / RESUME
  // ============================================================================

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

  // ============================================================================
  // QUIT
  // ============================================================================

  void onQuit() {
    final prev = status;
    setState(() => status = 'paused');
    pulseController.stop();
    _sendTimerUpdateToESP32();

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: errorIndicatorRed.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.exit_to_app_rounded,
                    color: errorIndicatorRed, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('End Session?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: dfNavyIndigo,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('Are you sure you want to quit early?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextGrey, fontSize: 15)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _InteractivePill(
                      onTap: () {
                        Navigator.pop(context);
                        if (!mounted) return;
                        setState(() => status = prev);
                        if (prev == 'running')
                          pulseController.repeat(reverse: true);
                        _sendTimerUpdateToESP32();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: secondaryTextGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InteractivePill(
                      onTap: () async {
                        _timer?.cancel();
                        if (_rikazConnected) await _debouncedLightOff();
                        if (mounted) Navigator.pop(context);

                        _sessionCompleted = false;

                        final int actual = _totalFocusSeconds ~/ 60;

                        if (actual < minimumSessionMinutes) {
                          await _endSessionInDB(
                              progress: null,
                              distraction: null,
                              overrideStatus: 'cancelled');
                          if (mounted)
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/tabs', (r) => false);
                          return;
                        }

                        // 10+ min
                        final bool cameraOn =
                            widget.isCameraDetectionEnabled ?? false;
                        String? p;
                        String d;

                        if (cameraOn) {
                          // كاميرا شغّالة: يسأل عن البروقرس يدوياً، يحسب الديستراكشن تلقائياً
                          p = await _showProgressLevelDialog();
                          d = _calculateDistractionLevel();
                        } else {
                          // كاميرا مطفية: يسأل عن كليهما يدوياً
                          p = await _showProgressLevelDialog();
                          d = await _showDistractionDialog();
                        }

                        await _endSessionInDB(progress: p, distraction: d);

                        if (mounted) {
                          await _showSummaryDialog(d, p ?? 'partially',
                              cameraCalculated: cameraOn);
                          _showMotivationalPopup(d, p ?? 'partially');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                            color: errorIndicatorRed,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: errorIndicatorRed.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ]),
                        child: const Center(
                            child: Text('End',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BREAK ACTIVITIES
  // ============================================================================

Future<void> _navigateToBreakActivities() async {
  if (!mounted || mode != 'break') return;

  _breakActivityOpen = true;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => GamesScreen(
        breakTimerListenable: _breakTimerNotifier,
      ),
    ),
  );

  _breakActivityOpen = false;

  if (!mounted) return;
  _sendTimerUpdateToESP32();
}

  // ============================================================================
  // CONNECTION MONITORING
  // ============================================================================

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Connection lost.')));
  }

  Future<void> _debouncedLightOff() async {
    if (!_rikazConnected || !_lightInitialized) return;
    final now = DateTime.now();
    if (_lastLightOffTime != null &&
        now.difference(_lastLightOffTime!) < _lightDebounceDelay) return;
    _lastLightOffTime = now;
    try {
      await RikazLightService.sendCommand(jsonEncode({"on": false}));
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
          'mode': mode
        },
        'config': {
          'style': widget.notificationStyle ?? 'strong',
          'subtleType': widget.subtleAlertType ?? 'light'
        }
      });
      await RikazLightService.sendCommand(cmd);
    } catch (_) {}
  }

  Future<void> _sendMotivationalMessage() async {
    if (!_rikazConnected || !_lightInitialized) return;
    try {
      await RikazLightService.sendCommand(
          jsonEncode({'motivation': 'show'}));
    } catch (_) {}
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  String formatTime(int s) {
    final minutes = (s ~/ 60).toString().padLeft(2, '0');
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

double get progressValue {
  final int totalPhaseSeconds =
      mode == 'break' ? breakMinutes * 60 : focusMinutes * 60;

  if (totalPhaseSeconds <= 0) return 0;

  return (timeLeft / totalPhaseSeconds).clamp(0.0, 1.0);
}

  // ============================================================================
  // DIALOGS — animated wrapper
  // ============================================================================

  Future<T?> _showAnimatedDialog<T>(
      {required BuildContext context, required Widget child}) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
    );
  }

  // ============================================================================
  // DIALOGS — progress
  // ============================================================================

  Future<String?> _showProgressLevelDialog() async {
    String? selected;
    await _showAnimatedDialog<String>(
      context: context,
      child: Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: dfTealCyan.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.track_changes_rounded,
                    size: 44, color: dfTealCyan),
              ),
              const SizedBox(height: 20),
              const Text("Goal Progress",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: dfNavyIndigo,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text("How much did you achieve?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: secondaryTextGrey)),
              const SizedBox(height: 28),
              _buildOptionCard(
                  title: "Fully",
                  subtitle: "Accomplished everything",
                  icon: Icons.check_circle,
                  color: dfTealCyan,
                  onTap: () async {
                    selected = 'fully';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
              _buildOptionCard(
                  title: "Partially",
                  subtitle: "Made good progress",
                  icon: Icons.trending_up,
                  color: breakColor,
                  onTap: () async {
                    selected = 'partially';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
              _buildOptionCard(
                  title: "Barely",
                  subtitle: "Struggled to stay focused",
                  icon: Icons.sentiment_dissatisfied,
                  color: errorIndicatorRed,
                  onTap: () async {
                    selected = 'barely';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  // ============================================================================
  // DIALOGS — distraction
  // ============================================================================

  Future<String> _showDistractionDialog() async {
    String selected = 'low';
    await _showAnimatedDialog<String>(
      context: context,
      child: Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: customModeColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.psychology_outlined,
                    size: 44, color: customModeColor),
              ),
              const SizedBox(height: 20),
              const Text("Distractions",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: dfNavyIndigo,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text("How distracted were you?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: secondaryTextGrey)),
              const SizedBox(height: 28),
              _buildOptionCard(
                  title: "Low",
                  subtitle: "Highly focused",
                  icon: Icons.battery_full,
                  color: dfTealCyan,
                  onTap: () async {
                    selected = 'low';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
              _buildOptionCard(
                  title: "Medium",
                  subtitle: "A few interruptions",
                  icon: Icons.battery_charging_full,
                  color: breakColor,
                  onTap: () async {
                    selected = 'medium';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
              _buildOptionCard(
                  title: "High",
                  subtitle: "Hard to ignore",
                  icon: Icons.battery_alert,
                  color: errorIndicatorRed,
                  onTap: () async {
                    selected = 'high';
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) Navigator.pop(context);
                  }),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  // ============================================================================
  // DIALOGS — summary
  // ============================================================================

  Future<void> _showSummaryDialog(
    String distraction,
    String progress, {
    bool cameraCalculated = false,
  }) async {
    await _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Session Summary",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: dfNavyIndigo,
                      letterSpacing: -0.5)),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                    color: primaryBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: subtleShadow),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _summaryRowUI(Icons.timer_outlined, 'Total Time',
                        '${(_totalFocusSeconds ~/ 60)} min', dfTealCyan),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: Colors.black12)),
                    _summaryRowUI(Icons.auto_graph_rounded, 'Progress',
                        progress.toUpperCase(), customModeColor),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: Colors.black12)),
                    // Distraction row with optional Auto badge (كاميرا شغّالة)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: breakColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(
                                    Icons.notifications_off_outlined,
                                    size: 20,
                                    color: breakColor)),
                            const SizedBox(width: 14),
                            const Text('Distractions',
                                style: TextStyle(
                                    color: secondaryTextGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            if (cameraCalculated) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dfTealCyan.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Auto',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: dfTealCyan)),
                              ),
                            ],
                          ],
                        ),
                        Text(distraction.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: dfNavyIndigo)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _InteractivePill(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                        color: dfNavyIndigo,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: dfNavyIndigo.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: const Center(
                        child: Text('Continue',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5))),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS — motivational
  // ============================================================================

  void _showMotivationalPopup(String distraction, String progress) {
    String message =
        "Every session is a learning experience. Keep going! 🚀";
    if (progress == 'fully' && distraction == 'low')
      message =
          "Outstanding! You maintained excellent focus and completed everything. 🌟";
    else if (progress == 'fully' && distraction == 'medium')
      message =
          "Great job! You pushed through the distractions and finished strong. 💪";
    else if (progress == 'fully' && distraction == 'high')
      message =
          "Incredible resilience! Despite heavy distractions, you completed your goals. 🔥";
    else if (progress == 'partially' && distraction == 'low')
      message =
          "Good focus quality! You stayed concentrated even though you didn't finish. 📈";
    else if (progress == 'partially' && distraction == 'medium')
      message =
          "Nice effort! You made solid progress despite some interruptions. ✨";
    else if (progress == 'partially' && distraction == 'high')
      message =
          "You tried your best in a challenging environment. Every small step counts. 🌱";
    else if (progress == 'barely' && distraction == 'low')
      message =
          "It happens! Even with focus, sometimes tasks are tough. You'll bounce back! 🔄";
    else if (progress == 'barely' && distraction == 'medium')
      message =
          "Challenging session, but you showed up! Identify what distracted you and try again! 💫";
    else if (progress == 'barely' && distraction == 'high')
      message =
          "This was a tough one. Learn from it and create a better setup next time. You've got this! 🌟";

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: dfTealCyan.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 64, color: dfTealCyan),
              ),
              const SizedBox(height: 28),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: dfNavyIndigo,
                      letterSpacing: -0.2)),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: _InteractivePill(
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/tabs', (route) => false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                        color: dfTealCyan,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: dfTealCyan.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: const Center(
                        child: Text('Finish',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5))),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // SHARED CARD WIDGET
  // ============================================================================

  Widget _buildOptionCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return _InteractivePill(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(20),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: dfNavyIndigo)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: secondaryTextGrey))
                ])),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: secondaryTextGrey),
          ],
        ),
      ),
    );
  }

  Widget _summaryRowUI(
      IconData icon, String label, String value, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: iconColor)),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    color: secondaryTextGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: dfNavyIndigo)),
      ],
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isPaused = status == 'paused';
    final timerDiameter = screenWidth * 0.75;

    Color activeRingColor =
        isPaused ? pausedColor : (mode == 'break' ? breakColor : dfTealCyan);

    return Scaffold(
      body: AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final double shift = isPaused ? 0 : bgShiftAnimation.value;
            final Alignment beginAlign =
                Alignment(-1.0 + shift, -1.0 - shift);
            final Alignment endAlign = Alignment(1.0 - shift, 1.0 + shift);

            Color topColor = isPaused
                ? pausedColor.withOpacity(0.3)
                : (mode == 'break'
                    ? breakColor.withOpacity(0.3)
                    : dfTealCyan.withOpacity(0.3));

            return AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: beginAlign,
                      end: endAlign,
                      colors: [
                    topColor,
                    primaryBackground,
                    primaryBackground
                  ])),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.03),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                          color: activeRingColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: activeRingColor.withOpacity(0.2),
                              width: 1.5)),
                      child: Text(
                          isPomodoro
                              ? (mode == 'break'
                                  ? 'BREAK TIME'
                                  : 'BLOCK $currentBlock / $totalBlocks')
                              : 'FOCUS SESSION',
                          style: TextStyle(
                              color: activeRingColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 2.5)),
                    ),
                    SizedBox(height: screenHeight * 0.06),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: isPaused ? 1.0 : pulseAnimation.value,
                          child: Container(
                            width: timerDiameter,
                            height: timerDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  activeRingColor
                                      .withOpacity(isPaused ? 0.05 : 0.15),
                                  activeRingColor.withOpacity(0.0)
                                ],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: timerDiameter * 0.85,
                          height: timerDiameter * 0.85,
                          child: CustomPaint(
                              painter: _ProgressRingPainter(
                                  progress: progressValue,
                                  color: activeRingColor)),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(formatTime(timeLeft),
                                style: const TextStyle(
                                    fontSize: 76,
                                    fontWeight: FontWeight.w300,
                                    color: dfNavyIndigo,
                                    letterSpacing: 2.0)),
                            const SizedBox(height: 8),
                            Text(
                                mode == 'break'
                                    ? 'TAKE A BREATH'
                                    : 'STAY FOCUSED',
                                style: TextStyle(
                                    color: secondaryTextGrey.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 3.0)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.08),
                    Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    if (mode != 'break') ...[
      _InteractivePill(
        onTap: onPauseResume,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: isPaused ? activeRingColor : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isPaused ? Colors.transparent : Colors.white,
              width: 1.5,
            ),
            boxShadow: isPaused
                ? [
                    BoxShadow(
                      color: activeRingColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ]
                : subtleShadow,
          ),
          child: Row(
            children: [
              Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: isPaused ? Colors.white : dfNavyIndigo,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                isPaused ? 'Resume' : 'Pause',
                style: TextStyle(
                  color: isPaused ? Colors.white : dfNavyIndigo,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 16),
    ],

    _InteractivePill(
      onTap: onQuit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(
          Icons.stop_rounded,
          color: dfNavyIndigo,
          size: 22,
        ),
      ),
    ),
  ],
),
                    
                    if (mode == 'break') ...[
                      const SizedBox(height: 20),
                      _InteractivePill(
                        onTap: _navigateToBreakActivities,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                              color: customModeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: customModeColor.withOpacity(0.3))),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videogame_asset_outlined,
                                    color: customModeColor, size: 20),
                                SizedBox(width: 8),
                                Text('Play Activity',
                                    style: TextStyle(
                                        color: customModeColor,
                                        fontWeight: FontWeight.bold))
                              ]),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 24.0),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(30),
                            border:
                                Border.all(color: Colors.white, width: 1.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SoundSection(
                            preselectedSoundId: widget.selectedSoundId,
                            preselectedSoundUrl: widget.selectedSoundUrl),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }
}

// ============================================================================
// INTERACTIVE PILL
// ============================================================================

class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractivePill({required this.child, required this.onTap});
  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// SOUND SECTION
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
        colorHex: '#68C29D',
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
          id: 'Rain',
          name: 'Rain',
          filePathUrl:
              'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
          iconName: 'water_drop_outlined',
          colorHex: '#5DADE2'),
      SoundOption(
          id: 'River',
          name: 'River',
          filePathUrl:
              'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
          iconName: 'waves_rounded',
          colorHex: '#4FC3F7'),
      SoundOption(
          id: 'White Noise',
          name: 'White Noise',
          filePathUrl:
              'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3',
          iconName: 'waves_rounded',
          colorHex: '#BA9CF1'),
    ];

    try {
      final res =
          await Supabase.instance.client.from('Sound_Option').select();
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
      if (sound.name == 'Rain' || sound.name == 'River')
        fallbackUrl =
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3';
      else if (sound.name == 'White Noise')
        fallbackUrl =
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3';
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
      _playSelectedSound(_currentSound);
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
            color: _currentSound.id == 'off'
                ? Colors.transparent
                : _currentSound.color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_currentSound.icon,
              color: _currentSound.id == 'off'
                  ? secondaryTextGrey
                  : _currentSound.color,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FutureBuilder<List<SoundOption>>(
            future: _soundsFuture,
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(
                    child: CircularProgressIndicator(color: dfTealCyan));
              final sounds = snap.data!;

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentSound.id,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: secondaryTextGrey),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dfNavyIndigo),
                  onChanged: (String? newId) {
                    if (newId != null) {
                      final newSound = sounds.firstWhere((s) => s.id == newId,
                          orElse: () => SoundOption.off());
                      setState(() => _currentSound = newSound);
                      _playSelectedSound(newSound);
                    }
                  },
                  items: sounds
                      .map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        _InteractivePill(
          onTap: _currentSound.id == 'off' ? () {} : _togglePlayPause,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _currentSound.id == 'off'
                  ? Colors.transparent
                  : _currentSound.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isSoundPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: _currentSound.id == 'off'
                  ? secondaryTextGrey.withOpacity(0.4)
                  : _currentSound.color,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SOUND OPTION MODEL
// ============================================================================

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
        colorHex: '#8B95A5',
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

// ============================================================================
// PROGRESS RING PAINTER
// ============================================================================

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
