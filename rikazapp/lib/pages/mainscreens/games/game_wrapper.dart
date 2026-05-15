import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// =============================================================================
// THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

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
  final ValueListenable<int>? secondsListenable;
  final bool showBackButton;
  final bool confirmOnClose;

  const GameWrapper({
    super.key,
    required this.child,
    this.isBreakSession = false,
    this.secondsListenable,
    this.showBackButton = true,
    this.confirmOnClose = false,

  });

  @override
  State<GameWrapper> createState() => GameWrapperState();
}

class GameWrapperState extends State<GameWrapper> {
  int getSecondsRemaining() {
    return widget.secondsListenable?.value ?? 0;
  }

  Future<T?> _showAnimatedDialog<T>({
    required BuildContext context,
    required Widget child,
  }) {
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

  Future<bool> _handleCloseAttempt() async {
  if (!widget.isBreakSession) {
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  final int secondsRemaining = getSecondsRemaining();

  if (secondsRemaining <= 0) {
    if (mounted) Navigator.of(context).pop(0);
    return false;
  }

  // Break games menu: return directly, no popup.
  if (!widget.confirmOnClose) {
    if (mounted) Navigator.of(context).pop(secondsRemaining);
    return false;
  }

  // Inside an actual game: show confirmation.
  final shouldReturn = await _showAnimatedDialog<bool>(
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
              decoration: BoxDecoration(
                color: dfTealCyan.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_return_rounded,
                color: dfTealCyan,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Leave Activity?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: dfNavyIndigo,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Return to the games menu?\nYour break timer will keep running.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryTextGrey,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _InteractivePill(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Stay',
                          style: TextStyle(
                            color: secondaryTextGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
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
                        color: dfTealCyan,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: dfTealCyan.withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Return',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
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

  if (shouldReturn == true && mounted) {
    Navigator.of(context).pop(secondsRemaining);
  }

  return false;
}

  String _formatSeconds(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldIntercept = widget.isBreakSession || widget.showBackButton;

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
child: const Icon(
  Icons.keyboard_return_rounded,
  color: dfNavyIndigo,
  size: 24,
),
                  ),
                ),
              ),

            if (widget.isBreakSession && widget.secondsListenable != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: subtleShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: dfTealCyan,
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: widget.secondsListenable!,
                        builder: (context, seconds, _) {
                          return Text(
                            _formatSeconds(seconds),
                            style: const TextStyle(
                              color: dfTealCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          );
                        },
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
// INTERACTIVE PILL
// =============================================================================

class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InteractivePill({
    required this.child,
    required this.onTap,
  });

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