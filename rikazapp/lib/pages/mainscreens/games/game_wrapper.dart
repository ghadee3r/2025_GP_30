import 'dart:async';
import 'package:flutter/material.dart';

// =============================================================================
// THEME COLORS
// =============================================================================
const Color dfNavyIndigo = Color(0xFF0C1446);
const Color dfDeepTeal = Color(0xFF175B73);
const Color errorIndicatorRed = Color(0xFFE57373);

class GameWrapper extends StatefulWidget {
  final Widget child; 
  final bool isBreakSession; 
  final int? initialSeconds; 

  const GameWrapper({
    super.key,
    required this.child,
    this.isBreakSession = false,
    this.initialSeconds,
  });

  @override
  State<GameWrapper> createState() => GameWrapperState();
}

class GameWrapperState extends State<GameWrapper> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    if (widget.isBreakSession && widget.initialSeconds != null) {
      _secondsRemaining = widget.initialSeconds!;
      _startTimer();
    } else {
      _secondsRemaining = 0;
    }
  }

  // --- SYNC METHODS ---
  int getSecondsRemaining() => _secondsRemaining;

  void updateSeconds(int newSeconds) {
    setState(() {
      _secondsRemaining = newSeconds;
    });
  }

  void pauseTimer() {
    _isPaused = true;
    _timer?.cancel();
  }

  void resumeTimer() {
    _isPaused = false;
    _startTimer();
  }
  // --------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPaused) return;

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _showTimeUpDialog();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerString {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _showTimeUpDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text("Break is Over!", style: TextStyle(color: dfNavyIndigo, fontWeight: FontWeight.bold)),
          content: const Text("Time to get back to work. Let's focus!"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal),
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).pop(0); 
              },
              child: const Text("Continue to Focus", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!widget.isBreakSession) return true;

    if (_secondsRemaining <= 0) return false;

    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Stop Activity?", style: TextStyle(color: dfNavyIndigo)),
        content: const Text(
          "Going back will cancel the current activity.\n\nReturn to previous screen?",
          style: TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No, Stay"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorIndicatorRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes, Quit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldQuit == true) {
      Navigator.of(context).pop(_secondsRemaining);
      return false; 
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            widget.child,

            // Close Button - Only show if Break
            if (widget.isBreakSession)
              Positioned(
                top: 50,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: dfNavyIndigo),
                    onPressed: () async {
                      await _onWillPop();
                    },
                  ),
                ),
              ),
            
            // NOTE: Removed the "else" block that added a back button for Main Menu. 
            // The GamesScreen AppBar will handle standard navigation now.

            // Timer Display - Only show if Break
            if (widget.isBreakSession)
              Positioned(
                top: 50,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: dfDeepTeal),
                      const SizedBox(width: 4),
                      Text(
                        _timerString,
                        style: const TextStyle(
                          color: dfDeepTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}