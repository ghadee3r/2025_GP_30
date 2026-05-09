import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4); 
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

List<BoxShadow> get subtleShadow => [
  BoxShadow(color: dfNavyIndigo.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
];

class ReflexScreen extends StatefulWidget {
  const ReflexScreen({super.key});

  @override
  State<ReflexScreen> createState() => _ReflexScreenState();
}

class _ReflexScreenState extends State<ReflexScreen> {
  // Dual players to prevent sound skipping during rapid taps
  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  bool _usePlayer1 = true;

  final Random _random = Random();
  
  int _currentStage = 1;
  final int _maxStages = 3;
  int _score = 0;
  int _targetsSpawned = 0;
  bool _hasWon = false;
  bool _isStageCleared = false;
  bool _gameInProgress = false; 
  String _compliment = "";

  final List<int> _targetsPerStage = [8, 12, 16];
  final List<Duration> _beatIntervals = [
    const Duration(milliseconds: 1800), 
    const Duration(milliseconds: 1500), 
    const Duration(milliseconds: 1300), 
  ];

  final List<String> _sounds = ['sounds/Pop1.mp3', 'sounds/Pop2.mp3'];
  List<TargetModel> _activeTargets = [];
  Timer? _gameTimer;

  @override
  void dispose() {
    _gameTimer?.cancel();
    _player1.dispose();
    _player2.dispose();
    super.dispose();
  }

  void _startGame() {
    if (!mounted) return;
    setState(() {
      _score = 0;
      _targetsSpawned = 0;
      _activeTargets = [];
      _isStageCleared = false;
      _hasWon = false;
      _gameInProgress = true; 
    });
    _startSpawner();
  }

  void _startSpawner() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(_beatIntervals[_currentStage - 1], (timer) {
      if (_targetsSpawned >= _targetsPerStage[_currentStage - 1]) {
        timer.cancel();
        _checkStageResult();
        return;
      }
      _spawnTarget();
    });
  }

  void _spawnTarget() {
    if (!mounted) return;
    double newX, newY;
    bool overlapping;
    int attempts = 0;

    // Maximum Spacing Logic: 130 pixels safety buffer
    do {
      newX = _random.nextDouble() * 160 - 80;
      newY = _random.nextDouble() * 240 - 120;
      overlapping = _activeTargets.any((t) => 
        sqrt(pow(t.x - newX, 2) + pow(t.y - newY, 2)) < 130); 
      attempts++;
    } while (overlapping && attempts < 30);

    final String id = "${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(100)}";
    final DateTime spawnTime = DateTime.now();

    setState(() {
      _targetsSpawned++;
      _activeTargets.add(TargetModel(id: id, x: newX, y: newY, spawnTime: spawnTime));
    });
    
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _activeTargets.removeWhere((t) => t.id == id));
      }
    });
  }

  void _handleTap(TargetModel target) {
    final int elapsed = DateTime.now().difference(target.spawnTime).inMilliseconds;
    bool inHitZone = elapsed >= 1100 && elapsed <= 1700;

    // Alternating between players to ensure every "Pop" is heard
    final AudioPlayer currentPlayer = _usePlayer1 ? _player1 : _player2;
    String randomSound = _sounds[_random.nextInt(_sounds.length)];
    
    currentPlayer.stop().then((_) => currentPlayer.play(AssetSource(randomSound)));
    _usePlayer1 = !_usePlayer1;

    if (mounted) {
      setState(() {
        if (inHitZone) _score++; 
        _activeTargets.removeWhere((t) => t.id == target.id);
      });
    }
  }

  void _checkStageResult() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _gameInProgress = false; 
      if (_score >= (_targetsPerStage[_currentStage - 1] * 0.60).floor()) {
        _compliment = _currentStage == 1 ? "You're doing great!" : (_currentStage == 2 ? "Your focus is incredible!" : "Absolutely Brilliant!");
        setState(() => _isStageCleared = true);
      } else {
        _compliment = "Deep breath... Let's try again.";
        setState(() => _isStageCleared = true);
      }
    });
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
        child: SafeArea(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
                );
              },
              child: _buildCurrentState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    if (_hasWon) return _buildFinalWinScreen();
    if (_isStageCleared) return _buildStagePrompt();
    if (!_gameInProgress) return _buildStartScreen();
    return _buildGameArea();
  }

  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.ads_click_rounded, size: 64, color: dfTealCyan),
          ),
          const SizedBox(height: 24),
          const Text("Reflex Popper", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Text(
            "Find your flow. Tap each orb exactly when the outer ring shrinks to fit it. Accuracy and rhythm are key.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryTextGrey, height: 1.5),
          ),
          const SizedBox(height: 48),
          _InteractiveButton(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: dfTealCyan,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: dfTealCyan.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: const Center(child: Text("Begin Session", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePrompt() {
    bool passed = _score >= (_targetsPerStage[_currentStage - 1] * 0.60).floor();
    bool isLastStage = _currentStage == _maxStages; 
    Color themeColor = passed ? dfTealCyan : errorIndicatorRed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(passed ? Icons.thumb_up_rounded : Icons.refresh_rounded, size: 48, color: themeColor),
          ),
          const SizedBox(height: 24),
          Text(_compliment, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text("Precision Score: $_score / ${_targetsPerStage[_currentStage - 1]}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: secondaryTextGrey)),
          const SizedBox(height: 48),
          _InteractiveButton(
            onTap: () {
              if (passed) {
                if (isLastStage) {
                  setState(() => _hasWon = true);
                } else {
                  setState(() => _currentStage++);
                  _startGame();
                }
              } else {
                _startGame();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Center(child: Text(passed ? (isLastStage ? "Finish" : "Next Stage") : "Retry Stage", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: dfTealCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dfTealCyan.withOpacity(0.2), width: 1.5)
          ),
          child: Text(
            "STAGE $_currentStage OF 3", 
            style: const TextStyle(fontSize: 12, color: dfTealCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)
          ),
        ),
        const SizedBox(height: 12),
        Text("$_score", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300, color: dfNavyIndigo, letterSpacing: -1.0)),
        Text("HITS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryTextGrey, letterSpacing: 2.0)),
        const SizedBox(height: 30),
        SizedBox(
          height: 450, width: 350, 
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: _activeTargets.map((target) => Positioned(
              key: ValueKey(target.id),
              left: 175 + target.x - 40, 
              top: 225 + target.y - 40,
              child: _buildZenBubble(target),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildZenBubble(TargetModel target) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTap(target),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Elegant closing-in aura
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 1.0, end: 0.0),
            builder: (context, double value, child) {
              return Container(
                width: 80 + (95 * value), 
                height: 80 + (95 * value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  border: Border.all(color: customModeColor.withOpacity(0.4 * value), width: 2.0)
                ),
              );
            },
          ),
          // Frosted Glass Bubble
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0, end: 1),
            curve: Curves.easeOutBack,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [dfTealCyan.withOpacity(0.1), dfTealCyan.withOpacity(0.3)],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: dfTealCyan.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: Center(
                    // Inner highlight core
                    child: Container(
                      width: 20, height: 20, 
                      decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.6), shape: BoxShape.circle)
                    )
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildFinalWinScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, size: 80, color: dfTealCyan),
          ),
          const SizedBox(height: 24),
          const Text("Cognitive Reset", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text("Excellent rhythm. Your mind is refreshed and ready to focus.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: secondaryTextGrey, height: 1.5)),
          const SizedBox(height: 48),
          _InteractiveButton(
            onTap: () => Navigator.pop(context), 
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: dfNavyIndigo,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: const Center(child: Text("Return to Menu", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ),
          ),
        ],
      ),
    );
  }
}

class TargetModel {
  final String id;
  final double x;
  final double y;
  final DateTime spawnTime; 
  TargetModel({required this.id, required this.x, required this.y, required this.spawnTime});
}

// =============================================================================
// REUSABLE INTERACTIVE SQUISH COMPONENT
// =============================================================================
class _InteractiveButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractiveButton({required this.child, required this.onTap});

  @override
  State<_InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<_InteractiveButton> {
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
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}