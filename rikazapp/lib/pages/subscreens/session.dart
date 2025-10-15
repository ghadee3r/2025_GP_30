import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ------------------------------------------------------------
// PlayAndPauseButton
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

// start in correct state
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
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
// SessionPage
// ------------------------------------------------------------
class SessionPage extends StatefulWidget {
final String sessionType;
final String duration;
final String? numberOfBlocks;

const SessionPage({
super.key,
required this.sessionType,
required this.duration,
this.numberOfBlocks,
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

String mode = 'focus';
String status = 'running';
int currentBlock = 1;
int timeLeft = 0;
List<int> completedBlocks = [];
Timer? _timer;

late AnimationController pulseController;

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

timeLeft = focusMinutes * 60;
startTimer();

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
setState(() => timeLeft--);
}
});
}

void onPhaseEnd() {
if (!isPomodoro) {
setState(() => status = 'idle');
_timer?.cancel();
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

// ✅ الذهاب لتبويب الألعاب داخل /tabs
void onGames() {
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 2, // 0=Home, 1=Progress, 2=Games, 3=Profile
);
}

void onQuit() {
_timer?.cancel();
showDialog(
context: context,
builder: (_) => AlertDialog(
title: const Text('End Session?'),
content: const Text('Are you sure you want to quit this session?'),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
TextButton(
onPressed: () {
Navigator.pop(context);
// ارجع للهوم داخل التبويبات
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 0,
);
},
child: const Text('Quit', style: TextStyle(color: Colors.red)),
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
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: (isBreak ? Colors.orange : Colors.blue).withOpacity(0.2),
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
isPomodoro ? (isBreak ? 'Break Time' : 'Focus Session') : 'Custom Session',
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
isPaused ? 'Paused' : (isBreak ? 'Relax & recharge' : 'Stay focused'),
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
isPomodoro ? 'Block $currentBlock of $totalBlocks' : 'Focus Duration',
style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
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
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
icon: const Icon(Icons.videogame_asset, color: Colors.white),
label: const Text(
'Games',
style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
padding: const EdgeInsets.symmetric(vertical: 14),
side: const BorderSide(color: Colors.red),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
icon: const Icon(Icons.stop, color: Colors.red),
label: const Text(
'Quit',
style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
],
),
),
),
),
);
}
}

// ------------------------------------------------------------
// Gradient Ring Painter
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
? const [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFFBBF24)]
: const [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
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
paint,
);
}

@override
bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ------------------------------------------------------------
// Pomodoro Block
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
isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.white);

final Color shadowColor = isCompleted
? Colors.green.withOpacity(0.35)
: isActive
? Colors.blue.withOpacity(0.35)
: Colors.black.withOpacity(0.15);

final String labelText = isCompleted
? 'Done'
: isActive
? (isRunning ? 'Active' : 'Pending')
: 'Pending';

return Column(
children: [
ScaleTransition(
scale: isActive && isRunning
? Tween(begin: 1.0, end: 1.06).animate(
CurvedAnimation(parent: controller, curve: Curves.easeInOut),
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
labelText,
style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
),
],
);
}
}
