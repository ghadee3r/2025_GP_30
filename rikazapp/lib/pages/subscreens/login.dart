import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';

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
const String _rikazLogoPath = "assets/images/RikazLogo.png"; 
const String _signupRoute = "/signup"; 
const String _forgotPasswordRoute = "/forgot-password"; 

final supabase = sb.Supabase.instance.client;
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

// ========= Google Sign-In =========
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // SEPARATE loading states so they never trigger each other
  bool _isSubmittingEmail = false;
  bool _isSubmittingGoogle = false;
  
  bool get _isAnySubmitting => _isSubmittingEmail || _isSubmittingGoogle;
  bool _obscurePassword = true;

  // Inline Validation States
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- MINIMALIST SPRING DIALOG (Only for system/network errors now) ---
  void _showMinimalDialog(BuildContext context, String title, String message, {bool isError = true}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: (isError ? errorIndicatorRed : dfTealCyan).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: isError ? errorIndicatorRed : dfTealCyan, size: 36),
                ),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: secondaryTextGrey, fontSize: 14, height: 1.4)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: _InteractivePill(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: isError ? errorIndicatorRed : dfTealCyan, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: (isError ? errorIndicatorRed : dfTealCyan).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                      child: const Center(child: Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(scale: Curves.easeOutBack.transform(anim.value), child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSubmittingGoogle = true);

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isSubmittingGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken; 

      if (idToken == null || accessToken == null) {
        throw Exception('Failed to retrieve tokens from Google.');
      }

      final sb.AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken, 
      );

      if (!mounted) return;

      if (response.user != null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false, arguments: 0);
      } else {
        _showMinimalDialog(context, "Login Error", "Failed to sign in with Google.");
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) _showMinimalDialog(context, "Login Error", "An error occurred during Google sign-in.");
    } finally {
      if (mounted) setState(() => _isSubmittingGoogle = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool hasValidationError = false;

    // Check if email is empty or badly formatted
    if (email.isEmpty) {
      _emailError = "Please enter your email address.";
      hasValidationError = true;
    } else if (!_emailRegex.hasMatch(email)) {
      _emailError = "Please enter a valid email address.";
      hasValidationError = true;
    }

    // Check ONLY if password is empty. No length rules!
    if (password.isEmpty) {
      _passwordError = "Please enter your password.";
      hasValidationError = true;
    }

    if (hasValidationError) {
      setState(() {}); 
      return; 
    }

    setState(() => _isSubmittingEmail = true);

    try {
      final sb.AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
         throw const sb.AuthException('Invalid login credentials.');
      }
      
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false, arguments: 0);

    } on sb.AuthException catch (e) {
      debugPrint("Supabase Login Error: ${e.message}");
      if (mounted) {
        setState(() {
          // Highlight BOTH fields for a generic credential error
          _emailError = "Incorrect email or password.";
          _passwordError = "Incorrect email or password.";
        });
      }
    } catch (e) {
      debugPrint("Generic Login Error: $e");
      if (mounted) {
        _showMinimalDialog(context, "Network Error", "An unexpected error occurred. Please check your connection.");
      }
    } finally {
      if (mounted) setState(() => _isSubmittingEmail = false);
    }
  }

  // --- GLASSMORPHIC INPUT FIELD ---
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
            color: Colors.transparent, // Ensures the outer pill background is transparent
            borderRadius: BorderRadius.circular(20),
            // Border turns red on error, white otherwise
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
                    filled: false, // <-- THIS FIXES THE UGLY WHITE BOX
                  ),
                  onChanged: (val) {
                    setState(() {
                      // If typing after a credential error, clear both fields at the same time
                      if (_emailError == "Incorrect email or password." || _passwordError == "Incorrect email or password.") {
                        _emailError = null;
                        _passwordError = null;
                      } else {
                        if (controller == _emailController) _emailError = null;
                        if (controller == _passwordController) _passwordError = null;
                      }
                    });
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
                        height: 120, 
                        width: 120,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: dfNavyIndigo, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text('Log in to continue your journey.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: secondaryTextGrey)),
                    const SizedBox(height: 40),

                    // Google Sign-In Glass Pill
                    _InteractivePill(
                      onTap: _isAnySubmitting ? () {} : _handleGoogleSignIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 2), boxShadow: subtleShadow),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSubmittingGoogle)
                              const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: dfNavyIndigo, strokeWidth: 2.5))
                            else
                              Image.asset('assets/images/google_logo.png', height: 22, width: 22, errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: dfNavyIndigo)),
                            
                            const SizedBox(width: 12),
                            Text(_isSubmittingGoogle ? "Connecting..." : "Continue with Google", style: const TextStyle(color: dfNavyIndigo, fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: secondaryTextGrey.withOpacity(0.2), thickness: 1.5)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: secondaryTextGrey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
                        Expanded(child: Divider(color: secondaryTextGrey.withOpacity(0.2), thickness: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 24),

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
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () { if (!_isAnySubmitting) Navigator.of(context).pushNamed(_forgotPasswordRoute); },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8.0, top: 4.0),
                          child: Text('Forgot Password?', style: TextStyle(color: dfTealCyan, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login Action Pill
                    _InteractivePill(
                      onTap: _isAnySubmitting ? () {} : _handleLogin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(color: dfNavyIndigo, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Center(
                          child: _isSubmittingEmail 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("Log In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: () { if (!_isAnySubmitting) Navigator.of(context).pushReplacementNamed(_signupRoute); },
                      child: const Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Don\'t have an account? ',
                            style: TextStyle(color: secondaryTextGrey, fontSize: 14),
                            children: [
                              TextSpan(text: 'Sign Up', style: TextStyle(color: dfTealCyan, fontWeight: FontWeight.bold)),
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