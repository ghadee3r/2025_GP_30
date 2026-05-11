import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// =============================================================================
// NEW MINIMALIST THEME COLORS
// =============================================================================
const Color dfTealCyan = Color(0xFF68C29D);
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color primaryBackground = Color(0xFFF2F6F9);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

List<BoxShadow> get subtleShadow => [
  BoxShadow(
    color: dfNavyIndigo.withOpacity(0.04),
    blurRadius: 20,
    offset: const Offset(0, 8),
  ),
];

// --- Constants ---
const String loginRoute = "/login"; 
final supabase = sb.Supabase.instance.client;
const String supabaseRedirectUrl = 'io.rikaz.app://reset-password'; 
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => ForgotPasswordState();
}

class ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  bool isSubmitting = false; 

  // Validation Error (Turns the box red)
  String? _emailError;
  // System Error (Only shows text, keeps box clean)
  String _errorMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // --- PREMIUM BLURRED SPRING DIALOG (Only for Success now) ---
  void _showSuccessDialog(BuildContext context, String title, String message, {VoidCallback? onOK}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.transparent, 
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  color: dfNavyIndigo.withOpacity(0.2),
                ),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: dfNavyIndigo.withOpacity(0.15), blurRadius: 40, spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_rounded, color: dfNavyIndigo, size: 64),
                      const SizedBox(height: 24),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: secondaryTextGrey, fontSize: 15, height: 1.5)),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: _InteractivePill(
                          onTap: () {
                            Navigator.pop(context); 
                            if (onOK != null) onOK(); 
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: dfNavyIndigo, 
                              borderRadius: BorderRadius.circular(20), 
                              boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                            ),
                            child: const Center(child: Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value), 
          child: Opacity(opacity: anim.value, child: child)
        );
      },
    );
  }

  Future<void> handlePasswordReset() async {
    final email = emailController.text.trim();

    setState(() {
      _emailError = null;
      _errorMessage = '';
    });

    bool hasValidationError = false;

    // Trigger validation errors (Red Borders)
    if (email.isEmpty) {
      _emailError = "Please enter your email address.";
      hasValidationError = true;
    } else if (!_emailRegex.hasMatch(email)) {
      _emailError = "Please enter a valid email address.";
      hasValidationError = true;
    }

    if (hasValidationError) {
      setState(() {});
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseRedirectUrl, 
      );
      
      if (!mounted) return;

      _showSuccessDialog(
        context, 
        "Check Your Email", 
        "If an account is associated with $email, a password reset link has been sent. Please check your spam folder.",
        onOK: () => Navigator.of(context).pushReplacementNamed(loginRoute)
      );

    } on sb.AuthException catch (e) {
      final message = e.message.toLowerCase();
      debugPrint("Supabase Reset Error: ${e.message}");

      if (mounted) {
        setState(() {
          // If Supabase tells us EXACTLY how many seconds to wait, show that.
          if (message.contains("seconds")) {
            final match = RegExp(r'\d+').firstMatch(message);
            final time = match != null ? match.group(0) : "60";
            _errorMessage = "Please wait $time seconds before requesting again.";
          } 
          // If we hit the Hourly spam limit, show a general warning.
          else if (message.contains("rate limit") || message.contains("too many requests") || message.contains("security purposes")) {
            _errorMessage = "Too many requests. Please try again later.";
          } 
          // Otherwise, just show the exact error Supabase gave us.
          else {
            _errorMessage = e.message; 
          }
        });
      }
    } catch (e) {
      debugPrint("Generic Reset Error: $e");
      if (mounted) setState(() => _errorMessage = "An unexpected network error occurred.");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // --- GLASSMORPHIC INPUT FIELD (With red borders ONLY for validation errors) ---
  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    String? errorText,
  }) {
    final bool hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6), 
            borderRadius: BorderRadius.circular(20),
            // Turns red ONLY if there is a validation error like empty/invalid format
            border: Border.all(color: hasError ? errorIndicatorRed.withOpacity(0.8) : Colors.white, width: 2), 
            boxShadow: subtleShadow,
          ),
          child: Row(
            children: [
              Icon(icon, color: hasError ? errorIndicatorRed : secondaryTextGrey.withOpacity(0.7), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  cursorColor: dfTealCyan,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dfNavyIndigo),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: secondaryTextGrey.withOpacity(0.6), fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (hasError) {
                      setState(() => _emailError = null);
                    }
                    if (_errorMessage.isNotEmpty) {
                      setState(() => _errorMessage = '');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: hasError ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 22, 
            padding: const EdgeInsets.only(left: 16),
            child: Text(errorText ?? '', style: const TextStyle(color: errorIndicatorRed, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)],
              )
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: _InteractivePill(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: subtleShadow,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: dfNavyIndigo, size: 24),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle, boxShadow: subtleShadow),
                      child: const Icon(Icons.lock_reset_rounded, size: 64, color: dfNavyIndigo),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text('Trouble logging in?', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
                    const SizedBox(height: 12),
                    const Text('Enter your email address and we will send you a link to reset your password.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: secondaryTextGrey, height: 1.4)),
                    const SizedBox(height: 40),

                    // Inputs
                    _buildGlassInput(
                      controller: emailController,
                      hintText: "Email address",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError, 
                    ),
                    
                    // FIXED HEIGHT SYSTEM ERROR MESSAGE (Doesn't affect the input borders)
                    Container(
                      height: 36,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      child: AnimatedOpacity(
                        opacity: _errorMessage.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(_errorMessage, style: const TextStyle(color: errorIndicatorRed, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                      ),
                    ),

                    _InteractivePill(
                      onTap: isSubmitting ? () {} : handlePasswordReset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(color: dfNavyIndigo, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Center(
                          child: isSubmitting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("Send Reset Link", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}