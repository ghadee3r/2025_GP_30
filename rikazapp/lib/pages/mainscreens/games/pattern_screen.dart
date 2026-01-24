import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// Project Theme Colors
const Color dfNavyIndigo = Color(0xFF0C1446);
const Color dfDeepTeal = Color(0xFF175B73);
const Color dfTealCyan = Color(0xFF287C85);

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

  void _showFeedback(bool isCorrect) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? "Perfect! Getting harder..." : "Oops! Let's try again."),
        backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Ensures centering
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Vertically centered
        crossAxisAlignment: CrossAxisAlignment.center, // Horizontally centered
        children: [
          if (_hasWon) ...[
            const Icon(Icons.check_circle_outline_rounded, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Brilliant!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: dfNavyIndigo, decoration: TextDecoration.none)),
            const SizedBox(height: 10),
            const Text("Sequence cleared.\nYour focus is sharpened!", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.none)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStage = 4);
                _generateNewLevel();
              },
              style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: const Text("Reset Game", style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            Text("Level ${_currentStage - 3} of 3", style: const TextStyle(fontSize: 18, color: dfTealCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
            const SizedBox(height: 10),
            Text(_isMemorizing ? "Memorize in $_memoCountdown..." : "Select the order!", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dfNavyIndigo, decoration: TextDecoration.none)),
            const SizedBox(height: 40),

            if (_isMemorizing)
              Center(
                child: Wrap(
                  spacing: 12, runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(_targetSequence.length, (index) {
                    return TweenAnimationBuilder(
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: _buildNumberCircle(_targetSequence[index]),
                        );
                      },
                    );
                  }),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_targetSequence.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _userSequence.length ? dfTealCyan : Colors.grey[300],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 50),
                  // Shuffled Selection Grid
                  Center(
                    child: Wrap(
                      spacing: 15, runSpacing: 15,
                      alignment: WrapAlignment.center,
                      children: _shuffledSelection.map((n) {
                        bool isTapped = _userSequence.contains(n);
                        return GestureDetector(
                          onTap: () => _handleNumberTap(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 65, height: 65,
                            decoration: BoxDecoration(
                              color: isTapped ? dfTealCyan.withOpacity(0.2) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: isTapped ? dfTealCyan : dfNavyIndigo.withOpacity(0.2), width: 2),
                            ),
                            child: Center(
                              child: Text("$n", style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, 
                                color: isTapped ? dfTealCyan : dfNavyIndigo,
                                decoration: TextDecoration.none)),
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
    );
  }

  Widget _buildNumberCircle(int n) {
    return Container(
      width: 65, height: 65,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [dfDeepTeal, dfTealCyan]),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: dfDeepTeal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Text("$n", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none)),
      ),
    );
  }
}