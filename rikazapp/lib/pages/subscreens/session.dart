import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:ui'; // <--- ADD THIS LINE
// ------------------------------------------------------------
// FrostedGlassContainer (New Utility Widget)
// ------------------------------------------------------------
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
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

// ------------------------------------------------------------
// PlayAndPauseButton (No change)
// ------------------------------------------------------------
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
    _controller =
        AnimationController(vsync: this, duration: widget.animationDuration);
    _animation =
        CurvedAnimation(parent: _controller!, curve: widget.animationCurve);

    // Start in correct state
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
    final animation = _animation ?? kAlwaysCompleteAnimation;
    final color = widget.isPaused ? Colors.green : Colors.blue;

    return FloatingActionButton.extended(
      backgroundColor: color,
      onPressed: widget.onPressed,
      label: Row(
        children: [
          Text(
            widget.isPaused ? 'Resume' : 'Pause',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: animation,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// SessionPage (Modified)
// ------------------------------------------------------------
class SessionPage extends StatefulWidget {
  final String sessionType;
    final String duration;
    final String? numberOfBlocks;
    final bool? isCameraDetectionEnabled; 
    final double? sensitivity;
    final String? notificationStyle;

  const SessionPage({
    super.key,
        required this.sessionType,
        required this.duration,
        this.numberOfBlocks,
        this.isCameraDetectionEnabled, 
        this.sensitivity,
        this.notificationStyle,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage>
    with SingleTickerProviderStateMixin {
  
  late bool isPomodoro;
  late int focusMinutes;
  late int breakMinutes;
  late int totalBlocks;

  // ✅ Supabase Logic Variables
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


// -------------------------------------------------------------------
// 💡 SUPABASE LOGIC START - الكود النظيف
// -------------------------------------------------------------------

  // دالة تسجيل بداية الجلسة (INSERT)
  Future<void> _startSessionInDB() async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      print('Error: User not authenticated. Cannot start session.');
      return;
    }
    
    final int plannedDuration = isPomodoro 
      ? (focusMinutes * totalBlocks) + (breakMinutes * totalBlocks)
      : focusMinutes; 

    _sessionStartTime = DateTime.now(); 

    try {
      // ✅ تم إزالة جميع الأعمدة التي تم تعيينها كـ NULLABLE في Supabase
      final response = await supabase
          .from('Focus_Session') 
          .insert({
            'user_id': currentUserId,
            'session_type': widget.sessionType, 
            'start_time': _sessionStartTime!.toIso8601String(),
            'duration_minutes': plannedDuration, // المدة المخطط لها (بدلاً من 0)
            
            // الأعمدة المتبقية التي يجب أن تكون موجودة في الإدراج (مثل Boolean أو String):
            'camera_monitored': widget.isCameraDetectionEnabled ?? false,
            // إذا كان لديك أي أعمدة أخرى NOT NULL (مثل progress_level, distraction_level)، يجب إضافتها هنا بقيمة افتراضية
            
          }).select('session_id'); 
          
      if (response.isNotEmpty) {
        setState(() {
          _currentSessionId = response.first['session_id'].toString(); 
        });
        print('✅ Session Started in DB with ID: $_currentSessionId');
      }
    } catch (e) {
      print('❌ Error starting session in DB: $e');
      print('DEBUG: RLS check, Table Name, or an unhandled NOT NULL constraint remains (e.g., progress_level, distraction_level).');
    }
  }

  // دالة تسجيل نهاية الجلسة (UPDATE)
  Future<void> _endSessionInDB({bool completed = false}) async {
    final supabase = Supabase.instance.client;

    // ✅ تم إضافة التحقق من null لحل الخطأ البرمجي
    if (_currentSessionId == null) {
      print('Error: Cannot end session. Session ID is missing.');
      return;
    }
    
    final int actualFocusDurationMinutes = (_totalFocusSeconds ~/ 60);

    // 🛑 شرط الحفظ: يجب أن يكون أكثر من دقيقة تركيز فعلي
    if (actualFocusDurationMinutes < 1) {
        print('❌ Session duration too short (less than 1 minute focus). Data not saved.');
        return; 
    }
    
    final endDateTime = DateTime.now().toIso8601String();
    
    try {
      // 💡 تحديث البيانات
      await supabase
          .from('Focus_Session') 
          .update({
            'end_time': endDateTime,
            'duration_minutes': actualFocusDurationMinutes, 
            // يمكن إضافة 'completed: completed' إذا كان لديك عمود لذلك
          })
          // ✅ استخدام علامة '!' بأمان بعد التحقق
          .eq('session_id', _currentSessionId!); 

      print('✅ Session ID: $_currentSessionId Ended and recorded successfully. Focus Time: $actualFocusDurationMinutes min');
    } catch (e) {
      print('❌ Error ending session in DB: $e');
    }
  }

// -------------------------------------------------------------------
// 💡 SUPABASE LOGIC END
// -------------------------------------------------------------------


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
      focusMinutes =
          int.tryParse(widget.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
      breakMinutes = 0;
      totalBlocks = 1;
    }

    timeLeft = focusMinutes * 60;
    startTimer();

    // 1. ✅ استدعاء دالة البدء
    _startSessionInDB(); 

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status != 'running') return;
      if (timeLeft <= 1) {
        onPhaseEnd();
      } else {
        setState(() {
          timeLeft--;
          // ✅ NEW: تراكم الثواني فقط في وضع التركيز
          if (mode == 'focus') { 
              _totalFocusSeconds++;
          }
        });
      }
    });
  }

  void onPhaseEnd() {
    if (!isPomodoro) {
      setState(() => status = 'idle');
      _timer?.cancel();
      // 2. ✅ إنهاء الجلسة المخصصة المكتملة
      _endSessionInDB(completed: true); 
      return;
    }

    if (mode == 'focus') {
      if (!completedBlocks.contains(currentBlock)) {
        completedBlocks.add(currentBlock);
      }
      setState(() {
        mode = 'break';
        timeLeft = breakMinutes * 60;
      });
    } else {
      final next = currentBlock + 1;
      if (next > totalBlocks) {
        setState(() {
          mode = 'focus';
          currentBlock = 1;
          completedBlocks.clear();
          timeLeft = focusMinutes * 60;
          status = 'idle';
        });
        _timer?.cancel();
        // 2. ✅ إنهاء جلسة البومودورو المكتملة
        _endSessionInDB(completed: true); 
      } else {
        setState(() {
          currentBlock = next;
          mode = 'focus';
          timeLeft = focusMinutes * 60;
        });
      }
    }
  }

  void onPauseResume() {
    setState(() {
      status = status == 'paused' ? 'running' : 'paused';
    });
  }

 void onQuit() {
    // 1. Store current status and set to 'paused' for display consistency
    //    We only stop the animation controller for visual feedback.
    final String previousStatus = status;
    setState(() => status = 'paused');
    pulseController.stop();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Are you sure you want to quit this session?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // 🛑 FIX: If 'Cancel' is pressed, restore the previous status 
              // and restart the pulsing animation if it was running.
              setState(() => status = previousStatus);
              if (previousStatus == 'running') {
                pulseController.repeat(reverse: true);
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // 🛑 FIX: Cancel the timer only when 'Quit' is confirmed
              _timer?.cancel(); 
              
              // 3. ✅ استدعاء دالة الإنهاء عند الخروج اليدوي
              _endSessionInDB(completed: false); 

              // Dispose animation again safely before navigating
              if (pulseController.isAnimating) pulseController.stop();
              pulseController.dispose(); // Should dispose here if navigating away

              // Then navigate
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home', 
                (route) => false,
              );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Games page coming soon!')),
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

  @override
  void dispose() {
    _timer?.cancel();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaused = status == 'paused';
    final bool isBreak = mode == 'break';

    final gradientColors = isPaused
        ? const [Color.fromARGB(255, 225, 227, 230), Color.fromARGB(255, 185, 196, 207)]
        : isBreak
            ? const [Color(0xFFFFF7ED), Color(0xFFFFFBEB), Color(0xFFFEF3C7)]
            : const [Color(0xFFF3F6FF), Color(0xFFEEF2FF), Color(0xFFEDE9FE)];

    final Color shadowColor = isPaused
        ? Colors.grey.withOpacity(0.3)
        : (isBreak
            ? const Color.fromARGB(160, 255, 172, 64).withOpacity(0.3)
            : const Color.fromARGB(78, 78, 52, 194).withOpacity(0.3));

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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isBreak ? Colors.orange : Colors.blue)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 290,
                      height: 290,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      height: 240,
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
                          style: const TextStyle(
                            fontSize: 36,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPaused
                              ? 'Paused'
                              : (isBreak
                                  ? 'Relax & recharge'
                                  : 'Stay focused'),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        isPomodoro
                            ? 'Block $currentBlock of $totalBlocks'
                            : 'Focus Duration',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: isBreak
                                ? ElevatedButton.icon(
                                    onPressed: onGames,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.videogame_asset,
                                        color: Colors.white),
                                    label: const Text(
                                      'Games',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : PlayAndPauseButton(
                                    isPaused: isPaused,
                                    onPressed: onPauseResume,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onQuit,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.stop, color: Colors.red),
                              label: const Text(
                                'Quit',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Pomodoro Blocks
                if (isPomodoro)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: List.generate(totalBlocks, (i) {
                      final blockNum = i + 1;
                      final isActive =
                          mode == 'focus' && currentBlock == blockNum;
                      final isCompleted =
                          completedBlocks.contains(blockNum);
                      return _PomodoroBlock(
                        blockNum: blockNum,
                        isActive: isActive,
                        isCompleted: isCompleted,
                        isRunning: status == 'running',
                        controller: pulseController,
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  const SoundSection(),


              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Gradient Ring Painter (No change)
// ------------------------------------------------------------
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
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2,
        2 * pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ------------------------------------------------------------
// Pomodoro Block (No change)
// ------------------------------------------------------------
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
    final Color bgColor =
        isCompleted ? Colors.green : (isActive ? const Color.fromRGBO(33, 150, 243, 1) : Colors.white);

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
            width: 56,
            height: 56,
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
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '$blockNum',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isCompleted
              ? 'Done'
              : isActive
                  ? (isRunning ? 'Active' : 'Pending')
                  : 'Pending',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Sound Model and Mock Data
// ------------------------------------------------------------
class Sound {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const Sound({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}

const List<Sound> kAvailableSounds = [
  Sound(
    id: 'off',
    name: 'No Sound',
    color: Color(0xFF64748B), // Slate-500
    icon: Icons.volume_off_rounded,
  ),
  Sound(
    id: 'rain',
    name: 'Rain',
    color: Color(0xFF6366F1), // Indigo-500
    icon: Icons.water_drop_outlined,
  ),
  Sound(
    id: 'forest',
    name: 'Forest',
    color: Color(0xFF10B981), // Emerald-500
    icon: Icons.forest_outlined,
  ),
  Sound(
    id: 'lofi',
    name: 'Lofi Beat',
    color: Color(0xFF7C3AED), // Purple-600
    icon: Icons.music_note_outlined,
  ),
];

// ------------------------------------------------------------
// SoundSection (Refactored Glassy Dropdown Widget)
// ------------------------------------------------------------
class SoundSection extends StatefulWidget {
  const SoundSection({super.key});

  @override
  State<SoundSection> createState() => _SoundSectionState();
}

class _SoundSectionState extends State<SoundSection> {
  // Mock state data for UI presentation
  String _currentSoundId = 'off';
  bool _isSoundPlaying = false;
  bool _isExpanded = false;

  void _onSoundSelected(String id) {
    setState(() {
      _currentSoundId = id;
      _isExpanded = false; // Collapse the dropdown
      
      if (id == 'off') {
        _isSoundPlaying = false;
      } else {
        _isSoundPlaying = true;
      }
      print('Sound selected: $id, Playing: $_isSoundPlaying');
    });
    // In a real app, call your audio service here
  }

  void _onPlayPauseTapped() {
    // Only allow play/pause if a sound is selected
    if (_currentSoundId != 'off') {
      setState(() {
        _isSoundPlaying = !_isSoundPlaying;
        print('Toggled Play/Pause. Playing: $_isSoundPlaying');
      });
      // In a real app, call your audio service here
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSound = kAvailableSounds.firstWhere((s) => s.id == _currentSoundId);
    final displayIcon = _isSoundPlaying ? currentSound.icon : Icons.volume_off_rounded;
    final displayColor = _isSoundPlaying ? currentSound.color : const Color(0xFF64748B);

    return FrostedGlassContainer(
      child: Column(
        children: [
          // 1. Header (Always Visible / Tap Target)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Current Sound Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: displayColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      displayIcon,
                      color: displayColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      _isSoundPlaying 
                        ? 'Playing: ${currentSound.name}' 
                        : 'Background Sound',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  
                  // Pause/Play Button
                  if (_currentSoundId != 'off')
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          _isSoundPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: displayColor,
                          size: 32,
                        ),
                        onPressed: _onPlayPauseTapped,
                      ),
                    ),

                  // Dropdown Indicator
                  Icon(
                    _isExpanded 
                        ? Icons.keyboard_arrow_up_rounded 
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // 2. Dropdown List
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(), // Collapsed state
            secondChild: Column( // Expanded list
              children: [
                const Divider(height: 1, color: Color.fromRGBO(255, 255, 255, 0.4), thickness: 1),
                ...kAvailableSounds.map((sound) {
                  // Only show 'No Sound' if it's not the currently active one
                  if (sound.id == _currentSoundId && _isSoundPlaying) return const SizedBox.shrink();
                  
                  return _SoundRow(
                    sound: sound,
                    isSelected: sound.id == _currentSoundId && _isSoundPlaying,
                    onTap: () => _onSoundSelected(sound.id),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// _SoundRow (Internal Widget for the list items)
// ------------------------------------------------------------
class _SoundRow extends StatelessWidget {
  final Sound sound;
  final bool isSelected;
  final VoidCallback onTap;

  const _SoundRow({
    required this.sound,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Row Thumbnail (Icon)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: sound.color.withOpacity(0.15),
              ),
              child: Icon(
                sound.icon,
                color: sound.color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Sound Name
            Expanded(
              child: Text(
                sound.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                ),
              ),
            ),
            // Selection Checkmark (if selected)
            if (isSelected)
              Icon(
                Icons.check,
                color: Colors.green.shade600,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}