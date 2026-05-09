import 'dart:async';
import 'package:flutter/material.dart';

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4); // Purple for memory target
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

List<BoxShadow> get subtleShadow => [
  BoxShadow(color: dfNavyIndigo.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
];

class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key});

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  int _currentStage = 4; // Start at 4 numbers
  final int _maxStage = 6; // End after stage 6
  List<int> _targetSequence = [];
  List<int> _userSequence = [];
  List<int> _shuffledSelection = [];
  bool _isMemorizing = true;
  bool _hasWon = false;
  
  int _memoCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _generateNewLevel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _generateNewLevel() {
    if (!mounted) return;
    setState(() {
      _isMemorizing = true;
      _userSequence = [];
      _hasWon = false;
      
      // 1. Generate unique random numbers for this stage
      var list = List.generate(15, (i) => i + 1);
      list.shuffle();
      _targetSequence = list.take(_currentStage).toList();

      // 2. Prepare the selection pool (just the target numbers, shuffled)
      _shuffledSelection = List.from(_targetSequence);
      _shuffledSelection.shuffle();

      // 3. Set the countdown (e.g., 1.5 seconds per number)
      _memoCountdown = _currentStage + 1;
    });

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_memoCountdown > 1) {
            _memoCountdown--;
          } else {
            _isMemorizing = false;
            timer.cancel();
          }
        });
      }
    });
  }

  void _handleNumberTap(int number) {
    if (_isMemorizing || _hasWon) return;

    setState(() {
      _userSequence.add(number);
    });

    if (_userSequence.last != _targetSequence[_userSequence.length - 1]) {
      _showFeedback(false);
      _generateNewLevel();
    } else if (_userSequence.length == _targetSequence.length) {
      if (_currentStage < _maxStage) {
        _showFeedback(true);
        _currentStage++;
        _generateNewLevel();
      } else {
        setState(() => _hasWon = true);
      }
    }
  }

  // Elegant Floating SnackBar Feedback
  void _showFeedback(bool isCorrect) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isCorrect ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              isCorrect ? "Perfect! Getting harder..." : "Oops! Let's try again.",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
            ),
          ],
        ),
        backgroundColor: isCorrect ? dfTealCyan : errorIndicatorRed,
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let wrapper background shine through
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)],
          )
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_hasWon) ...[
                // Minimalist Win State
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events_rounded, size: 80, color: dfTealCyan),
                ),
                const SizedBox(height: 24),
                const Text("Brilliant!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text(
                  "Sequence cleared.\nYour working memory is sharpened.", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontSize: 16, color: secondaryTextGrey, height: 1.5)
                ),
                const SizedBox(height: 48),
                _InteractiveBubble(
                  onTap: () {
                    setState(() => _currentStage = 4);
                    _generateNewLevel();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      color: dfTealCyan,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: dfTealCyan.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: const Text("Play Again", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
              ] else ...[
                // Elegant Level Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: customModeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: customModeColor.withOpacity(0.2), width: 1.5)
                  ),
                  child: Text(
                    "LEVEL ${_currentStage - 3} OF 3", 
                    style: const TextStyle(fontSize: 12, color: customModeColor, fontWeight: FontWeight.bold, letterSpacing: 2.0)
                  ),
                ),
                const SizedBox(height: 24),
                
                // Animated Status Header
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _isMemorizing ? "Memorize in $_memoCountdown..." : "Select the order!", 
                    key: ValueKey<bool>(_isMemorizing),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)
                  ),
                ),
                const SizedBox(height: 48),

                if (_isMemorizing)
                  // Memorize Phase - Purple glowing orbs
                  Center(
                    child: Wrap(
                      spacing: 16, runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: List.generate(_targetSequence.length, (index) {
                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          tween: Tween<double>(begin: 0, end: 1),
                          curve: Curves.easeOutBack,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: _buildNumberCircle(_targetSequence[index], true),
                            );
                          },
                        );
                      }),
                    ),
                  )
                else
                  // Play Phase - Frosted Teal bubbles
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_targetSequence.length, (index) {
                          bool isFilled = index < _userSequence.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: isFilled ? 24 : 10, 
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isFilled ? dfTealCyan : Colors.grey.shade300,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 50),
                      
                      // Shuffled Selection Grid
                      Center(
                        child: Wrap(
                          spacing: 16, runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: _shuffledSelection.map((n) {
                            bool isTapped = _userSequence.contains(n);
                            return _InteractiveBubble(
                              onTap: () => _handleNumberTap(n),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  color: isTapped ? dfTealCyan.withOpacity(0.15) : Colors.white.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isTapped ? dfTealCyan : Colors.white, width: 2),
                                  boxShadow: isTapped ? [] : subtleShadow,
                                ),
                                child: Center(
                                  child: Text(
                                    "$n", 
                                    style: TextStyle(
                                      fontSize: 24, 
                                      fontWeight: FontWeight.w600, 
                                      color: isTapped ? dfTealCyan : dfNavyIndigo,
                                    )
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Frosted glowing orb for the memorization phase
  Widget _buildNumberCircle(int n, bool isTarget) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [customModeColor.withOpacity(0.8), customModeColor],
        ),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: customModeColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Center(
        child: Text("$n", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

// =============================================================================
// REUSABLE INTERACTIVE SQUISH COMPONENT
// =============================================================================
class _InteractiveBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractiveBubble({required this.child, required this.onTap});

  @override
  State<_InteractiveBubble> createState() => _InteractiveBubbleState();
}

class _InteractiveBubbleState extends State<_InteractiveBubble> {
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
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}