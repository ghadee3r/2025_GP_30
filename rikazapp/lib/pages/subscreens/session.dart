import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:ui'; 

// ------------------------------------------------------------
// FrostedGlassContainer (Utility Widget - Made Flexible)
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

// ------------------------------------------------------------
// PlayAndPauseButton (Modified for Flexibility)
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
                        fontSize: screenWidth * 0.04
                        ),
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

// ------------------------------------------------------------
// SessionPage (Modified for Flexibility)
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
// 💡 SUPABASE LOGIC START - (Functionality Untouched)
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
         final response = await supabase
               .from('Focus_Session') 
               .insert({
                  'user_id': currentUserId,
                  'session_type': widget.sessionType, 
                  'start_time': _sessionStartTime!.toIso8601String(),
                  'duration_minutes': plannedDuration, 
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
         print('DEBUG: RLS check, Table Name, or an unhandled NOT NULL constraint remains (e.g., progress_level, distraction_level).');
      }
   }

   // دالة تسجيل نهاية الجلسة (UPDATE)
   Future<void> _endSessionInDB({bool completed = false}) async {
      final supabase = Supabase.instance.client;

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
               })
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

    // Initialization logic preserved exactly
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

   // Timer logic preserved exactly
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
         }
      });
   }

   // Phase transition logic preserved exactly
   void onPhaseEnd() {
      if (!mounted) return;
      
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

   // Pause/Resume logic preserved exactly
   void onPauseResume() {
      if (!mounted) return;
      setState(() {
         status = status == 'paused' ? 'running' : 'paused';
      });
      if (status == 'running') {
            pulseController.repeat(reverse: true);
      } else {
            pulseController.stop();
      }
   }

   // Quit logic preserved exactly
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
                  onPressed: () {
                     _timer?.cancel(); 
                     
                     try {
                        pulseController.dispose(); 
                     } catch(_) { }
                     
                     _endSessionInDB(completed: false); 

                     Navigator.pop(dialogContext); 

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

   // Game navigation logic preserved exactly
   void onGames() {
      // Navigate to games page
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

   @override
   void dispose() {
      _timer?.cancel();
      
      try {
            if (pulseController.isAnimating) pulseController.stop();
            pulseController.dispose();
      } catch (_) { }
      
      super.dispose();
   }

   @override
   Widget build(BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final horizontalPadding = screenWidth * 0.05;

      final bool isPaused = status == 'paused';
      final bool isBreak = mode == 'break';

      // Gradients and Shadows (Logic untouched)
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

      // Proportional Timer Dimensions
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
                  // FLEXIBLE PADDING
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: screenHeight * 0.02),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.center,
                     children: [
                        // Header
                        Container(
                           // FLEXIBLE PADDING
                           padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.008),
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
                                       fontSize: screenWidth * 0.035,
                                    ),
                                 ),
                              ],
                           ),
                        ),
                        SizedBox(height: screenHeight * 0.04),

                        // Timer
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
                                             : (isBreak
                                                   ? 'Relax & recharge'
                                                   : 'Stay focused'),
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

                        // Controls
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
                                                                  borderRadius: BorderRadius.circular(screenWidth * 0.035)),
                                                      ),
                                                      icon: Icon(Icons.videogame_asset,
                                                            color: Colors.white, size: screenWidth * 0.06),
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
                                                padding:
                                                      EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                                                side: const BorderSide(color: Colors.red),
                                                shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(screenWidth * 0.035),
                                                ),
                                             ),
                                             icon: Icon(Icons.stop, color: Colors.red, size: screenWidth * 0.06),
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

                        // Pomodoro Blocks
                        if (isPomodoro)
                           Column(
                              children: [
                                 Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: screenWidth * 0.04,
                                    runSpacing: screenWidth * 0.04,
                                    children: List.generate(totalBlocks, (i) {
                                       final blockNum = i + 1;
                                       final isActive = mode == 'focus' && currentBlock == blockNum;
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

// ------------------------------------------------------------
// Gradient Ring Painter (No fixed size changes needed here, relies on parent size)
// ------------------------------------------------------------
class _GradientRingPainter extends CustomPainter {
// ... (Logic untouched)
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
// Pomodoro Block (Modified for Flexibility)
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
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final blockDiameter = screenWidth * 0.14; 
      final blockFontSize = screenWidth * 0.04; 

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
                        ? Icon(Icons.check, color: Colors.white, size: screenWidth * 0.06) 
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
               style: TextStyle(fontSize: screenWidth * 0.03, color: const Color(0xFF64748B)), 
            ),
         ],
      );
   }
}

// ------------------------------------------------------------
// Sound Model and Mock Data (Unchanged)
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
   Sound(id: 'off', name: 'No Sound', color: Color(0xFF64748B), icon: Icons.volume_off_rounded),
   Sound(id: 'rain', name: 'Rain', color: Color(0xFF6366F1), icon: Icons.water_drop_outlined),
   Sound(id: 'forest', name: 'Forest', color: Color(0xFF10B981), icon: Icons.forest_outlined),
   Sound(id: 'lofi', name: 'Lofi Beat', color: Color(0xFF7C3AED), icon: Icons.music_note_outlined),
];

// ------------------------------------------------------------
// SoundSection (Refactored Glassy Dropdown Widget - Modified for Flexibility)
// ------------------------------------------------------------
class SoundSection extends StatefulWidget {
   const SoundSection({super.key});

   @override
   State<SoundSection> createState() => _SoundSectionState();
}

class _SoundSectionState extends State<SoundSection> {
   // Mock state data for UI presentation (Logic untouched)
   String _currentSoundId = 'off';
   bool _isSoundPlaying = false;
   bool _isExpanded = false;

   void _onSoundSelected(String id) {
      if (!mounted) return;
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
   }

   void _onPlayPauseTapped() {
      if (_currentSoundId != 'off') {
            if (!mounted) return;
         setState(() {
            _isSoundPlaying = !_isSoundPlaying;
            print('Toggled Play/Pause. Playing: $_isSoundPlaying');
         });
      }
   }

   @override
   Widget build(BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final currentSound = kAvailableSounds.firstWhere((s) => s.id == _currentSoundId);
      final displayIcon = _isSoundPlaying ? currentSound.icon : Icons.volume_off_rounded;
      final displayColor = _isSoundPlaying ? currentSound.color : const Color(0xFF64748B);

      return FrostedGlassContainer(
         child: Column(
            children: [
               // 1. Header (Always Visible / Tap Target)
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
                           // Current Sound Icon
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
                           // Title
                           Expanded(
                              child: Text(
                                 _isSoundPlaying 
                                    ? 'Playing: ${currentSound.name}' 
                                    : 'Background Sound',
                                 style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                    fontSize: screenWidth * 0.04, 
                                 ),
                              ),
                           ),
                           
                           // Pause/Play Button
                           if (_currentSoundId != 'off')
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

                           // Dropdown Indicator
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

               // 2. Dropdown List
               AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isExpanded 
                        ? CrossFadeState.showSecond 
                        : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(), 
                  secondChild: Column( 
                     children: [
                        const Divider(height: 1, color: Color.fromRGBO(255, 255, 255, 0.4), thickness: 1),
                        ...kAvailableSounds.map((sound) {
                           if (sound.id != 'off' && sound.id == _currentSoundId && _isSoundPlaying) return const SizedBox.shrink();
                           
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
// _SoundRow (Internal Widget for the list items - Modified for Flexibility)
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
      final screenWidth = MediaQuery.of(context).size.width;
      final rowHorizontalPadding = screenWidth * 0.04; 

      return InkWell(
         onTap: onTap,
         child: Padding(
            padding: EdgeInsets.symmetric(horizontal: rowHorizontalPadding, vertical: screenWidth * 0.03),
            child: Row(
               children: [
                  // Row Thumbnail (Icon)
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
                  // Sound Name
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
                  // Selection Checkmark (if selected)
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