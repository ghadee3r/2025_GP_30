import 'dart:async';
import 'package:flutter/material.dart';

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color errorIndicatorRed = Color(0xFFE57373);
const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

class GameWrapper extends StatefulWidget {
  final Widget child; 
  final bool isBreakSession; 
  final int? initialSeconds; 
  final bool showBackButton; // Controls if the floating button appears

  const GameWrapper({
    super.key,
    required this.child,
    this.isBreakSession = false,
    this.initialSeconds,
    this.showBackButton = true, // True for games, False for the main menu!
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

  // Animated Spring Dialog Builder
  Future<T?> _showAnimatedDialog<T>({required BuildContext context, required Widget child}) {
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

  Future<void> _showTimeUpDialog() async {
    return _showAnimatedDialog<void>(
      context: context,
      child: PopScope(
        canPop: false, 
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.timer_off_rounded, size: 64, color: dfTealCyan),
                ),
                const SizedBox(height: 28),
                const Text("Break is Over!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dfNavyIndigo, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                const Text(
                  "Time to get back to work. Let's focus!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: secondaryTextGrey, height: 1.4),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: _InteractivePill(
                    onTap: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).pop(0); 
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: dfTealCyan, 
                        borderRadius: BorderRadius.circular(20), 
                        boxShadow: [BoxShadow(color: dfTealCyan.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                      ),
                      child: const Center(
                        child: Text('Continue to Focus', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleCloseAttempt() async {
    if (!widget.isBreakSession) {
      Navigator.of(context).pop();
      return true;
    }
    
    if (_secondsRemaining <= 0) return false;

    final shouldQuit = await _showAnimatedDialog<bool>(
      context: context,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.exit_to_app_rounded, color: errorIndicatorRed, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Stop Activity?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dfNavyIndigo, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              const Text(
                "Going back will cancel the current activity.\n\nReturn to previous screen?",
                textAlign: TextAlign.center, 
                style: TextStyle(color: secondaryTextGrey, fontSize: 14, height: 1.4)
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _InteractivePill(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('No, Stay', style: TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.bold, fontSize: 15))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InteractivePill(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: errorIndicatorRed, 
                          borderRadius: BorderRadius.circular(16), 
                          boxShadow: [BoxShadow(color: errorIndicatorRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                        ),
                        child: const Center(child: Text('Yes, Quit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
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

    if (shouldQuit == true) {
      if (mounted) Navigator.of(context).pop(_secondsRemaining);
      return false; 
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Only intercept the back button if we are in a game or a Break Session
    bool shouldIntercept = widget.isBreakSession || widget.showBackButton;

    return PopScope(
      canPop: !shouldIntercept,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!widget.isBreakSession) {
          Navigator.of(context).pop(result);
          return;
        }
        await _handleCloseAttempt();
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.child,

            // Floating back/close button (Strictly honors showBackButton)
            if (widget.showBackButton)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                child: _InteractivePill(
                  onTap: () async => await _handleCloseAttempt(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: subtleShadow,
                    ),
                    child: Icon(
                      widget.isBreakSession ? Icons.close_rounded : Icons.arrow_back_rounded, 
                      color: dfNavyIndigo, 
                      size: 24
                    ),
                  ),
                ),
              ),

            // Timer Display - Only show if Break
            if (widget.isBreakSession)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: subtleShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: dfTealCyan),
                      const SizedBox(width: 8),
                      Text(
                        _timerString,
                        style: const TextStyle(
                          color: dfTealCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.0,
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

// =============================================================================
// REUSABLE INTERACTIVE SQUISH COMPONENT
// =============================================================================
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
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}