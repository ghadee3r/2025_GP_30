import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// Relaxing Theme Colors
const Color dfNavyIndigo = Color(0xFF0C1446);
const Color dfDeepTeal = Color(0xFF175B73);
const Color dfTealCyan = Color(0xFF287C85);
const Color dfLightSeafoam = Color(0xFF87ACA3);

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
        // More encouraging, Rikaz-specific words
        _compliment = _currentStage == 1 ? "You're doing great!" : (_currentStage == 2 ? "Your focus is incredible!" : "Absolutely Brilliant!");
        setState(() => _isStageCleared = true);
      } else {
        _compliment = "Deep breath... Let's try again!";
        setState(() => _isStageCleared = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasWon) _buildFinalWinScreen()
            else if (_isStageCleared) _buildStagePrompt()
            else if (!_gameInProgress) _buildStartScreen() 
            else _buildGameArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa_rounded, size: 80, color: dfLightSeafoam),
          const SizedBox(height: 20),
          const Text("Zen Rhythm", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: dfNavyIndigo, decoration: TextDecoration.none)),
          const SizedBox(height: 20),
          // Simple game explanation
          const Text(
            "Find your flow. Tap each circle exactly when the outer ring shrinks to fit it. Accuracy and rhythm are key to clearing each stage.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.4, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: const Text("Begin Session", style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePrompt() {
    bool passed = _score >= (_targetsPerStage[_currentStage - 1] * 0.60).floor();
    bool isLastStage = _currentStage == _maxStages; //

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_compliment, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: dfDeepTeal, decoration: TextDecoration.none)),
        const SizedBox(height: 15),
        Text("Precision Score: $_score", style: const TextStyle(fontSize: 20, color: dfNavyIndigo, decoration: TextDecoration.none)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
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
          style: ElevatedButton.styleFrom(backgroundColor: dfTealCyan, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          // Dynamic button text: No "Next Stage" on stage 3
          child: Text(passed ? (isLastStage ? "Finish" : "Next Stage") : "Retry Stage", style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Stage $_currentStage", style: const TextStyle(fontSize: 18, color: dfTealCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
        Text("Points: $_score", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dfNavyIndigo, decoration: TextDecoration.none)),
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
              child: _buildZenCircle(target),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildZenCircle(TargetModel target) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTap(target),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 1.0, end: 0.0),
            builder: (context, double value, child) {
              return Container(
                width: 80 + (95 * value), 
                height: 80 + (95 * value),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dfLightSeafoam.withOpacity(0.5), width: 2.5)),
              );
            },
          ),
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [dfLightSeafoam, dfTealCyan]),
                    boxShadow: [BoxShadow(color: dfLightSeafoam.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)],
                  ),
                  child: Center(child: Container(width: 25, height: 25, decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle))),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildFinalWinScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 100, color: dfLightSeafoam),
        const SizedBox(height: 20),
        const Text("Cognitive Reset Complete", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: dfNavyIndigo, decoration: TextDecoration.none)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.pop(context), 
          style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: const Text("Return", style: TextStyle(color: Colors.white)),
        ),
      ],
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