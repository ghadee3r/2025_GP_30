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
  String mode = 'focus';
  String status = 'running';
  int currentBlock = 1;
  int timeLeft = 0;
  List<int> completedBlocks = [];
  Timer? _timer;
  late AnimationController pulseController;
  Timer? _connectionCheckTimer;
  bool _completionHandled = false;
  bool _isShowingProgressDialog = false;
  bool _isNavigatingAway = false;
  DateTime? _lastLightOffTime;
  static const Duration _lightDebounceDelay = Duration(seconds: 2);
  static const int minimumSessionMinutes = 10;

  Future<void> _debouncedLightOff() async {
    if (!_rikazConnected || !_lightInitialized) return;
    final now = DateTime.now();
    if (_lastLightOffTime != null && now.difference(_lastLightOffTime!) < _lightDebounceDelay) return;
    _lastLightOffTime = now;
    try { await RikazLightService.turnOff(); } catch (e) { debugPrint('Light error: $e'); }
  }

  Future<void> _sendTimerUpdateToESP32() async {
    if (!_rikazConnected || !_lightInitialized) return;
    try {
      final cmd = jsonEncode({'timer': {'minutes': timeLeft ~/ 60, 'seconds': timeLeft % 60, 'status': status, 'mode': mode}});
      await RikazLightService.sendCommand(cmd);
    } catch (e) { debugPrint('LCD error: $e'); }
  }

  Future<void> _sendMotivationalMessage() async {
    if (!_rikazConnected || !_lightInitialized) return;
    try { await RikazLightService.sendCommand(jsonEncode({'motivation': 'show'})); } catch (_) {}
  }

  Future<bool> _handleLightAndResume() async {
    if (!mounted) return false;
    bool success = true;
    if (RikazConnectionState.isConnected && !_lightInitialized) {
      success = mode == 'focus' ? await RikazLightService.setFocusLight() : await RikazLightService.setBreakLight();
      if (success) { _rikazConnected = true; _lightInitialized = true; _startConnectionMonitoring(); }
    } else if (_rikazConnected && _lightInitialized) {
      success = mode == 'focus' ? await RikazLightService.setFocusLight() : await RikazLightService.setBreakLight();
    }
    if (!success && (_rikazConnected || _lightInitialized)) return false;
    setState(() => status = 'running');
    pulseController.repeat(reverse: true);
    _sendTimerUpdateToESP32();
    return true;
  }

  Future<void> _handleReconnectAttempt() async {
    if (!mounted) return;
    final RikazDevice? selectedDevice = await showDialog<RikazDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(),
    );
    if (!mounted || selectedDevice == null) return;
    RikazConnectionState.isConnected = true;
    _rikazConnected = true;
    await _handleLightAndResume();
  }

  void _handleLightCommandFailure({bool showSnackbar = true}) {
    if (!mounted) return;
    if (status == 'running') { setState(() => status = 'paused'); pulseController.stop(); _sendTimerUpdateToESP32(); }
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Connection lost. Paused.'),
        action: SnackBarAction(label: 'Reconnect', onPressed: () => _handleReconnectAttempt()),
      ));
    }
    if (!RikazConnectionState.isConnected) { _rikazConnected = false; _lightInitialized = false; }
  }

  Future<void> _startSessionInDB() async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final planned = isPomodoro ? (focusMinutes * totalBlocks) : focusMinutes;
    _sessionStartTime = DateTime.now();
    try {
      final res = await supabase.from('Focus_Session').insert({
        'user_id': uid, 'session_type': widget.sessionType, 'start_time': _sessionStartTime!.toIso8601String(),
        'planned_duration': planned, 'pomodoro_type': isPomodoro ? '$focusMinutes-$breakMinutes' : null,
        'camera_monitored': widget.isCameraDetectionEnabled ?? false,
      }).select('session_id');
      if (res.isNotEmpty && mounted) setState(() => _currentSessionId = res.first['session_id'].toString());
    } catch (e) { debugPrint('DB Start Error: $e'); }
  }

  Future<void> _endSessionInDB({bool completed = false}) async {
    if (_completionHandled) return;
    final supabase = Supabase.instance.client;
    if (_currentSessionId == null) return;
    final actual = (_totalFocusSeconds ~/ 60);
    if (actual < minimumSessionMinutes) {
      _completionHandled = true;
      try { await supabase.from('Focus_Session').delete().eq('session_id', _currentSessionId!); } catch (_) {}
      return;
    }
    _completionHandled = true;
    String? progress = await _showProgressLevelDialog() ?? 'partially';
    try {
      await supabase.from('Focus_Session').update({
        'end_time': DateTime.now().toIso8601String(), 'actual_duration': actual, 'progress_level': progress,
      }).eq('session_id', _currentSessionId!);
    } catch (e) { debugPrint('DB End Error: $e'); }
  }

  // === NAVIGATION LOGIC ===
  Future<void> _navigateToBreakActivities() async {
    _timer?.cancel(); 
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamesScreen(breakSecondsRemaining: timeLeft),
      ),
    );

    if (mounted) {
      if (result is int) {
        setState(() => timeLeft = result);
      }
      
      if (timeLeft <= 0 && mode == 'break') {
        onPhaseEnd();
      } else {
        startTimer();
      }
    }
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status != 'running') return;
      if (!mounted) { _timer?.cancel(); return; }
      setState(() {
        if (timeLeft > 0) timeLeft--;
        if (mode == 'focus') _totalFocusSeconds++;
      });
      _sendTimerUpdateToESP32();
      if (timeLeft <= 0) onPhaseEnd();
    });
  }

  void onPhaseEnd() async { 
    if (!mounted || _completionHandled) return;
    if (!isPomodoro) {
      _timer?.cancel(); setState(() => status = 'idle');
      if (_rikazConnected) { await RikazLightService.sendCommand(jsonEncode({'sessionComplete': 'true'})); await _debouncedLightOff(); }
      await _endSessionInDB(completed: true);
      if (mounted && !_isNavigatingAway) { _isNavigatingAway = true; Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false); }
      return;
    }
    if (mode == 'focus') {
      if (!completedBlocks.contains(currentBlock)) { completedBlocks.add(currentBlock); _sendMotivationalMessage(); }
      if (currentBlock >= totalBlocks) {
        _timer?.cancel(); setState(() { mode = 'focus'; status = 'idle'; });
        if (_rikazConnected) { await RikazLightService.sendCommand(jsonEncode({'sessionComplete': 'true'})); await _debouncedLightOff(); }
        await _endSessionInDB(completed: true);
        if (mounted && !_isNavigatingAway) { _isNavigatingAway = true; Navigator.pushNamedAndRemoveUntil(context, '/tabs', (route) => false); }
        return;
      }
      // REVERTED TO 5 MINUTES FOR BREAK
      setState(() { mode = 'break'; timeLeft = 5 * 60; }); 
      if (_rikazConnected) { await RikazLightService.setBreakLight(); _sendTimerUpdateToESP32(); }
    } else {
      // BACK TO FOCUS - KEPT AT 3 SECONDS FOR TESTING
      setState(() { currentBlock++; mode = 'focus'; timeLeft = 3; });
      if (_rikazConnected) { await RikazLightService.setFocusLight(); _sendTimerUpdateToESP32(); }
    }
    startTimer();
  }

  @override
  void initState() {
    super.initState();
    isPomodoro = widget.sessionType == 'pomodoro';
    if (isPomodoro) {
      if (widget.duration == '25min') { focusMinutes = 25; breakMinutes = 5; } 
      else { focusMinutes = 50; breakMinutes = 10; }
      totalBlocks = int.tryParse(widget.numberOfBlocks ?? '4') ?? 4;
    } else {
      focusMinutes = int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
      breakMinutes = 0; totalBlocks = 1;
    }
    _rikazConnected = widget.rikazConnected ?? false;
    
    // KEEP FOCUS AT 3 SECONDS FOR TESTING
    timeLeft = 3; 
    
    startTimer();
    _startSessionInDB();
    if (_rikazConnected) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && status == 'running') {
          if (await RikazLightService.setFocusLight()) { _lightInitialized = true; _startConnectionMonitoring(); _sendTimerUpdateToESP32(); }
          else _handleLightCommandFailure();
        }
      });
    }
    pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !RikazConnectionState.isConnected) { timer.cancel(); return; }
      if (!await RikazLightService.isConnected()) {
        timer.cancel(); await RikazLightService.disconnect();
        RikazConnectionState.isConnected = false;
        if (mounted) setState(() { _rikazConnected = false; _lightInitialized = false; });
        _handleLightCommandFailure(showSnackbar: true);
      }
    });
  }

  void onPauseResume() async {
    if (!mounted) return;
    if (status == 'paused') await _handleLightAndResume();
    else { setState(() => status = 'paused'); pulseController.stop(); _sendTimerUpdateToESP32(); }
  }

  void onQuit() {
    final prev = status;
    setState(() => status = 'paused'); pulseController.stop();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('End Session?'), content: Text('Are you sure?'),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); if (mounted) setState(() => status = prev); if (prev == 'running') pulseController.repeat(reverse: true); }, child: Text('No')),
        ElevatedButton(onPressed: () async {
          _timer?.cancel(); if (_rikazConnected) await _debouncedLightOff();
          Navigator.pop(ctx); await _endSessionInDB();
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/tabs', (r) => false);
        }, child: Text('Yes')),
      ],
    ));
  }

  Future<String?> _showProgressLevelDialog() async { return null; } 

  String formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  double get progress => (1 - (timeLeft / max((mode == 'focus' ? focusMinutes : breakMinutes) * 60, 1))).clamp(0, 1);
  Color get backgroundColor => status == 'paused' ? pausedBgColor : (mode == 'break' ? breakBgColor : focusBgColor);
  Color get ringColor => status == 'paused' ? pausedBgColor.withOpacity(0.6) : (mode == 'break' ? Colors.orange : accentThemeColor);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isPaused = status == 'paused';
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(screenWidth * 1.5)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: [
                SizedBox(width: double.infinity, height: screenHeight * 0.05),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(20)),
                  child: Text(isPomodoro ? (mode == 'break' ? 'Break Time' : 'Pomodoro Focus') : 'Custom Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: screenHeight * 0.04),
                Stack(alignment: Alignment.center, children: [
                  Container(width: timerDiameter, height: timerDiameter, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30)])),
                  SizedBox(width: timerDiameter * 0.92, height: timerDiameter * 0.92, child: CustomPaint(painter: _ProgressRingPainter(progress: progress, color: ringColor))),
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(formatTime(timeLeft), style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: primaryTextDark)),
                    Text(mode == 'break' ? 'Take a rest' : 'Stay focused', style: TextStyle(color: secondaryTextGrey)),
                  ]),
                ]),
                SizedBox(height: screenHeight * 0.04),
                
                if (mode == 'break') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                    onPressed: _navigateToBreakActivities,
                    icon: Icon(Icons.videogame_asset_outlined),
                    label: Text('Play Activity'),
                  ),
                  SizedBox(height: 20),
                ],
                
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: isPaused ? pausedBgColor : accentThemeColor, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                  onPressed: onPauseResume,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: errorIndicatorRed, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                  onPressed: onQuit,
                  icon: Icon(Icons.close),
                  label: Text('End Session'),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                        padding: EdgeInsets.all(16),
                        child: SoundSection(preselectedSoundId: widget.selectedSoundId, preselectedSoundName: widget.selectedSoundName, preselectedSoundUrl: widget.selectedSoundUrl),
                      ),
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
}

class _ProgressRingPainter extends CustomPainter {
  final double progress; final Color color;
  _ProgressRingPainter({required this.progress, required this.color});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    final bg = Paint()..color = Colors.grey[300]!..style = PaintingStyle.stroke..strokeWidth = 12;
    canvas.drawCircle(Offset(size.width/2, size.height/2), (size.width-12)/2, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width/2, size.height/2), radius: (size.width-12)/2), -pi/2, 2*pi*progress, false, p);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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