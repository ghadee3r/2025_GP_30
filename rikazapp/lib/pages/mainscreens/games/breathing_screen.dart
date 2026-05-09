import 'package:flutter/material.dart';

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _status = "Inhale (4s)";

  @override
  void initState() {
    super.initState();
    
    // Core functionality preserved: 16 second loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16), // Full cycle (4s * 4)
    )..repeat();

    // UI FIX: Changed to a TweenSequence so the scale actually matches Box Breathing!
    // Grow (4s) -> Hold (4s) -> Shrink (4s) -> Hold (4s)
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 25),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.6).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 25),
      TweenSequenceItem(tween: ConstantTween<double>(0.6), weight: 25),
    ]).animate(_controller);

    _controller.addListener(() {
      final val = _controller.value;
      String nextStatus;
      
      if (val < 0.25) {
        nextStatus = "Inhale (4s)";
      } else if (val < 0.50) {
        nextStatus = "Hold (4s)";
      } else if (val < 0.75) {
        nextStatus = "Exhale (4s)";
      } else {
        nextStatus = "Hold (4s)";
      }

      // Performance boost: Only rebuild if the text actually changed
      if (_status != nextStatus) {
        setState(() => _status = nextStatus);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent, // Allows GameWrapper's background to show
      body: Container(
        // Soft calming gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)],
          )
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Elegant Header
                Text(
                  "Mindful Breathing",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextGrey.withOpacity(0.8),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Airy, minimalist status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _status,
                    key: ValueKey<String>(_status),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      color: dfNavyIndigo,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 80),
                
                // The Breathtaking Glass Orb
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        width: screenWidth * 0.65, 
                        height: screenWidth * 0.65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Frosted glass effect with a subtle teal tint
                          gradient: RadialGradient(
                            colors: [
                              dfTealCyan.withOpacity(0.15),
                              dfTealCyan.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            // Beautiful soft glow that expands with the orb
                            BoxShadow(
                              color: dfTealCyan.withOpacity(0.25 * _animation.value), 
                              blurRadius: 50, 
                              spreadRadius: 10 * _animation.value
                            )
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.air_rounded, 
                            color: dfTealCyan.withOpacity(0.8), 
                            size: 64
                          )
                        ),
                      ),
                    );
                  }
                ),
                
                const SizedBox(height: 100),
                
                // Clean instructional text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Follow the orb. Breathe in as it expands, hold, and breathe out as it shrinks.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, 
                      color: secondaryTextGrey, 
                      fontWeight: FontWeight.w500,
                      height: 1.5
                    )
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}