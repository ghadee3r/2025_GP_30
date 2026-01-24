import 'package:flutter/material.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _status = "Inhale";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16), // Full cycle (4s * 4)
    )..repeat();

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addListener(() {
      final val = _controller.value;
      if (val < 0.25) setState(() => _status = "Inhale (4s)");
      else if (val < 0.50) setState(() => _status = "Hold (4s)");
      else if (val < 0.75) setState(() => _status = "Exhale (4s)");
      else setState(() => _status = "Hold (4s)");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF175B73), decoration: TextDecoration.none)),
            const SizedBox(height: 50),
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF87ACA3), const Color(0xFF175B73).withOpacity(0.5)]),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                ),
                child: const Center(child: Icon(Icons.air, color: Colors.white, size: 50)),
              ),
            ),
            const SizedBox(height: 60),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text("Follow the circle: Breathe in as it grows, hold, and breathe out as it shrinks.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.none)),
            ),
          ],
        ),
      ),
    );
  }
}