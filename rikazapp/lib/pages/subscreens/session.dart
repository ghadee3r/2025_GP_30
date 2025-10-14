import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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

class _SessionPageState extends State<SessionPage> {
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
      setState(() {
        status = 'idle';
      });
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
        // session end
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
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = status == 'paused'
        ? const Color(0xFFE5E7EB)
        : (mode == 'break' ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mode == 'break'
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
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
                        color: mode == 'break' ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Text(
                      isPomodoro
                          ? (mode == 'break' ? 'Break Time' : 'Focus Session')
                          : 'Custom Session',
                      style: TextStyle(
                        color: mode == 'break' ? Colors.orange[900] : Colors.blue[900],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        mode == 'break' ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(formatTime(timeLeft),
                          style: const TextStyle(
                              fontSize: 36,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(
                        status == 'paused'
                            ? 'Paused'
                            : (mode == 'focus'
                                ? 'Stay focused'
                                : 'Relax & recharge'),
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

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
                          color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onPauseResume,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  status == 'paused' ? Colors.green : Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: Icon(
                                status == 'paused'
                                    ? Icons.play_arrow
                                    : Icons.pause,
                                color: Colors.white),
                            label: Text(
                              status == 'paused' ? 'Resume' : 'Pause',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
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
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.stop, color: Colors.red),
                            label: const Text('Quit',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Blocks (Pomodoro only)
              if (isPomodoro)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(totalBlocks, (i) {
                    final blockNum = i + 1;
                    final isActive = mode == 'focus' && currentBlock == blockNum;
                    final isCompleted = completedBlocks.contains(blockNum);
                    return Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? Colors.green
                                : isActive
                                    ? Colors.blue
                                    : Colors.white,
                            border: Border.all(
                                color: isActive
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                                width: 2),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white)
                              : Text(
                                  '$blockNum',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCompleted
                              ? 'Done'
                              : isActive
                                  ? (status == 'paused' ? 'Pending' : 'Active')
                                  : 'Pending',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
