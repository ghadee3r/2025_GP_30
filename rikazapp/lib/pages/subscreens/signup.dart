import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// =============================================================================
// THEME COLORS
// =============================================================================
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

const Color primaryThemeColor = dfDeepBlue;      
const Color accentThemeColor = dfTealCyan;       
const Color lightestAccentColor = dfLightSeafoam; 

const Color primaryBackground = Color(0xFFF7F7F7); 
const Color cardBackground = Color(0xFFFFFFFF);  

const Color primaryTextDark = dfNavyIndigo;      
const Color secondaryTextGrey = Color(0xFF6B6B78); 

const Color errorIndicatorRed = Color(0xFFE57373); 

// ========= Constants =========
const String _rikazLogoPath = "assets/images/RikazLogo.png";
final supabase = sb.Supabase.instance.client;

// ========= Helpers =========
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

void _showAlert(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: cardBackground,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark)),
        content: Text(message, style: const TextStyle(color: primaryTextDark)),
        actions: <Widget>[
          TextButton(
            child: const Text("OK", style: TextStyle(color: dfDeepTeal)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

// ========= Widget =========
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

  // UX State: Track which fields have errors to change border color
  bool _emailHasError = false;
  bool _passwordHasError = false;
  bool _confirmPasswordHasError = false;

  // UX State: Specific error message strings
  String _passwordErrorMessage = '';
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

  void _showVerifiedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: accentThemeColor, size: 70),
              const SizedBox(height: 20),
              const Text("Account Verified!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextDark)),
              const SizedBox(height: 12),
              const Text("Your email has been successfully verified.\nPlease log in to continue.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: secondaryTextGrey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("Back to Login", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ➕ NEW: Dialog to show when email is sent (replaces the low green text)
  void _showEmailSentDialog(String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, color: dfDeepTeal, size: 70),
              const SizedBox(height: 20),
              const Text("Check Your Email", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextDark)),
              const SizedBox(height: 12),
              Text("We have sent a verification link to:\n$email", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: secondaryTextGrey)),
              const SizedBox(height: 8),
              const Text("Please check your inbox (and spam) to activate your account.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: secondaryTextGrey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: dfDeepTeal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("OK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
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
      _emailHasError = false;
      _passwordHasError = false;
      _confirmPasswordHasError = false;
      _passwordErrorMessage = '';
      _postSignupMessage = '';
    });

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => _emailHasError = true);
      _showAlert(context, "Invalid Email", "Please enter a valid email address.");
      return;
    }
    
    if (password != confirmPassword) {
      setState(() {
        _passwordHasError = true;
        _confirmPasswordHasError = true;
        _passwordErrorMessage = "Passwords do not match.";
      });
      return;
    }

    String? requirementError = _validatePasswordRequirements(password);
    if (requirementError != null) {
      setState(() {
        _passwordHasError = true;
        _passwordErrorMessage = requirementError;
      });
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
      
      // --- IDENTITIES LOGIC ---
      if (response.user != null && (response.user!.identities == null || response.user!.identities!.isEmpty)) {
        // User already exists
        setState(() {
          _emailHasError = true; 
          _postSignupMessage = "This email is already registered. Please log in instead.";
          _isSuccessMessage = false; 
        });

      } else if (response.user != null) {
        // Success
        // 🌟 UPDATED: Instead of setting text, show the beautiful dialog
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
      if (errorMessage.contains('User already registered') || 
          errorMessage.contains('already has an account')) {
        setState(() {
          _emailHasError = true; 
          _postSignupMessage = "This email is in use. Please log in.";
          _isSuccessMessage = false;
        });
      } else {
         _showAlert(context, "Signup Error", errorMessage);
      }
      
    } catch (e) {
      if (!mounted) return;
      _showAlert(context, "Signup Error", "An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
    bool obscureText = false,
    bool autocorrect = true,
    bool hasError = false, 
    VoidCallback? onToggleVisibility, 
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: autocorrect,
      cursorColor: dfDeepTeal,
      style: const TextStyle(fontSize: 16, color: primaryTextDark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: secondaryTextGrey),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: hasError ? errorIndicatorRed : secondaryTextGrey, 
            width: hasError ? 2.0 : 1.0
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: hasError ? errorIndicatorRed : dfDeepTeal, 
            width: 2
          ),
        ),
        suffixIcon: onToggleVisibility != null ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: hasError ? errorIndicatorRed : secondaryTextGrey,
          ),
          onPressed: onToggleVisibility,
        ) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Image.asset(_rikazLogoPath, height: 150, width: 150),
              const SizedBox(height: 10),

              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextDark),
              ),
              const SizedBox(height: 24),

              _buildTextInput(
                controller: _nameController,
                hintText: "Full Name",
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              
              _buildTextInput(
                controller: _emailController,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                hasError: _emailHasError, 
              ),
              const SizedBox(height: 12),
              
              _buildTextInput(
                controller: _passwordController,
                hintText: "Password",
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscurePassword,
                autocorrect: false,
                hasError: _passwordHasError, 
                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 12),
              
              _buildTextInput(
                controller: _confirmPasswordController,
                hintText: "Confirm Password",
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscureConfirmPassword,
                autocorrect: false,
                hasError: _confirmPasswordHasError, 
                onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),

              if (_passwordErrorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: errorIndicatorRed, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _passwordErrorMessage,
                          style: const TextStyle(fontSize: 12, color: errorIndicatorRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else 
                const SizedBox(height: 24), 

              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dfDeepTeal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isSubmitting ? "Creating..." : "Sign Up",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),

              // Only show this for ERRORS now. Success uses the Dialog.
              if (_postSignupMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _postSignupMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      color: _isSuccessMessage ? accentThemeColor : errorIndicatorRed, 
                    ),
                  ),
                ),
                
              GestureDetector(
                onTap: _isSubmitting ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Text(
                    'Already have an account? Log in',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: primaryThemeColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}