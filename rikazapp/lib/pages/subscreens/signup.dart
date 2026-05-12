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

// ========= Constants =========
const String _rikazLogoPath = "assets/images/RikazLogo.png";
final supabase = sb.Supabase.instance.client;
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController(); 

  // Inline Validation States
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  
  String _postSignupMessage = ''; 
  bool _isSuccessMessage = true; 
  bool _isSubmitting = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  StreamSubscription<sb.AuthState>? _authStateSubscription;
  bool _verificationDialogShown = false; 

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final sb.AuthChangeEvent event = data.event;
      if (event == sb.AuthChangeEvent.signedIn && !_isSubmitting && !_verificationDialogShown) {
        supabase.auth.signOut();
        setState(() => _verificationDialogShown = true);
        if (mounted) _showVerifiedSuccessDialog();
      }
    });
  }

  // --- PREMIUM BLURRED DIALOG (For Success & Checking Email) ---
  void _showBlurDialog({required String title, required String message, required IconData icon, Color iconColor = dfNavyIndigo}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
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
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: dfNavyIndigo.withOpacity(0.3)),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95), 
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.15), blurRadius: 40, spreadRadius: 5)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor, size: 44),
                      ),
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
                            if (title == "Account Verified!") {
                              Navigator.of(context).pushReplacementNamed('/login');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(color: dfNavyIndigo, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                            child: Center(child: Text(title == "Account Verified!" ? 'Back to Login' : 'OK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5))),
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
        return Transform.scale(scale: Curves.easeOutBack.transform(anim.value), child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  void _showVerifiedSuccessDialog() {
    _showBlurDialog(
      title: "Account Verified!", 
      message: "Your email has been successfully verified.\nPlease log in to continue.", 
      icon: Icons.check_circle_rounded, 
      iconColor: dfTealCyan
    );
  }

  void _showEmailSentDialog(String email) {
    _showBlurDialog(
      title: "Check Your Email", 
      message: "We have sent a verification link to:\n$email\n\nPlease check your inbox (and spam) to activate your account.", 
      icon: Icons.mark_email_read_rounded, 
      iconColor: dfNavyIndigo
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authStateSubscription?.cancel(); 
    super.dispose();
  }

  String? _validatePasswordRequirements(String password) {
    if (password.length < 8) return "Must be at least 8 characters.";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Must contain an uppercase letter.";
    if (!RegExp(r'[a-z]').hasMatch(password)) return "Must contain a lowercase letter.";
    if (!RegExp(r'\d').hasMatch(password)) return "Must contain a number.";
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return "Must contain a special character.";
    return null; 
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _postSignupMessage = '';
    });

    bool hasValidationErrors = false;

    if (name.isEmpty) {
      _nameError = "Full name is required.";
      hasValidationErrors = true;
    }

    if (email.isEmpty) {
      _emailError = "Email address is required.";
      hasValidationErrors = true;
    } else if (!_emailRegex.hasMatch(email)) {
      _emailError = "Please enter a valid email address.";
      hasValidationErrors = true;
    }

    if (password.isEmpty) {
      _passwordError = "Password is required.";
      hasValidationErrors = true;
    } else {
      String? requirementError = _validatePasswordRequirements(password);
      if (requirementError != null) {
        _passwordError = requirementError;
        hasValidationErrors = true;
      }
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = "Please confirm your password.";
      hasValidationErrors = true;
    } else if (password != confirmPassword) {
      _confirmPasswordError = "Passwords do not match.";
      hasValidationErrors = true;
    }

    if (hasValidationErrors) {
      return; 
    }

    setState(() => _isSubmitting = true);

    try {
      final sb.AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: 'rikazapp://login',  
      );

      if (!mounted) return;
      
      if (response.user != null && (response.user!.identities == null || response.user!.identities!.isEmpty)) {
        setState(() {
          _emailError = "This email is already registered. Please log in.";
        });
      } else if (response.user != null) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        _showEmailSentDialog(email); 
      } else {
        setState(() {
          _postSignupMessage = 'An error occurred. Please try again.';
          _isSuccessMessage = false;
        });
      }
      
    } on sb.AuthException catch (e) { 
      if (!mounted) return;
      
      String errorMessage = e.message;
      if (errorMessage.contains('User already registered') || errorMessage.contains('already has an account')) {
        setState(() {
          _emailError = "This email is already registered. Please log in.";
        });
      } else {
         setState(() {
           _postSignupMessage = errorMessage;
           _isSuccessMessage = false;
         });
      }
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postSignupMessage = "An unexpected network error occurred.";
        _isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- GLASSMORPHIC INPUT FIELD WITH NO "UGLY LIGHT" BORDERS ---
  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    bool obscureText = false,
    String? errorText,
    VoidCallback? onToggleVisibility,
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
            color: Colors.transparent, 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2), // ALWAYS WHITE
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
                  obscureText: obscureText,
                  autocorrect: false,
                  cursorColor: dfTealCyan,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dfNavyIndigo),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: secondaryTextGrey.withOpacity(0.6), fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false, // <-- ADDED THIS
                  ),
                  onChanged: (val) {
                    if (hasError) {
                      setState(() {
                        if (controller == _nameController) _nameError = null;
                        if (controller == _emailController) _emailError = null;
                        if (controller == _passwordController) _passwordError = null;
                        if (controller == _confirmPasswordController) _confirmPasswordError = null;
                      });
                    }
                  },
                ),
              ),
              if (onToggleVisibility != null)
                IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: secondaryTextGrey.withOpacity(0.7), size: 20),
                  onPressed: onToggleVisibility,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(
                      tag: 'rikaz_logo',
                      child: Image.asset(
                        _rikazLogoPath, 
                        height: 100, 
                        width: 100,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text('Create Account', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text('Join us and reclaim your depth.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: secondaryTextGrey)),
                    const SizedBox(height: 40),

                    _buildGlassInput(
                      controller: _nameController,
                      hintText: "Full Name",
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
                      errorText: _nameError,
                    ),
                    
                    _buildGlassInput(
                      controller: _emailController,
                      hintText: "Email address",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError, 
                    ),
                    
                    _buildGlassInput(
                      controller: _passwordController,
                      hintText: "Password",
                      icon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: _obscurePassword,
                      errorText: _passwordError, 
                      onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    
                    _buildGlassInput(
                      controller: _confirmPasswordController,
                      hintText: "Confirm Password",
                      icon: Icons.lock_reset_rounded,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: _obscureConfirmPassword,
                      errorText: _confirmPasswordError, 
                      onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),

                    const SizedBox(height: 16), 

                    _InteractivePill(
                      onTap: _isSubmitting ? () {} : _handleSignup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(color: dfNavyIndigo, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Center(
                          child: _isSubmitting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("Sign Up", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_postSignupMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          _postSignupMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w600,
                            color: _isSuccessMessage ? dfTealCyan : errorIndicatorRed, 
                          ),
                        ),
                      ),
                      
                    GestureDetector(
                      onTap: _isSubmitting ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                      child: const Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: secondaryTextGrey, fontSize: 14),
                            children: [
                              TextSpan(text: 'Log in', style: TextStyle(color: dfTealCyan, fontWeight: FontWeight.bold)),
                            ],
                          ),
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