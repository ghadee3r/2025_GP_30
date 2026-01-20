import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:google_sign_in/google_sign_in.dart';

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

// --- Constants ---
const String _rikazLogoPath = "assets/images/RikazLogo.png"; 
const String _signupRoute = "/signup"; 
const String _forgotPasswordRoute = "/forgot-password"; 

final supabase = sb.Supabase.instance.client;

// ========= Google Sign-In =========
// Since you added the json/plist files, we don't need hardcoded IDs here.
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

// --- Custom Alert Dialog Helper ---
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
            child: const Text("OK", style: TextStyle(color: primaryThemeColor)),
            onPressed: () {
              Navigator.of(context).pop(); 
            },
          ),
        ],
      );
    },
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasLoginError = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSubmitting = true);

    try {
      // Force account selection screen
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken; // REQUIRED for Supabase

      if (idToken == null || accessToken == null) {
        throw Exception('Failed to retrieve tokens from Google.');
      }

      // Sign in with Supabase using BOTH tokens
      final sb.AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken, // DO NOT OMIT
      );

      if (!mounted) return;

      if (response.user != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/tabs',
          (route) => false,
          arguments: 0,
        );
      } else {
        _showAlert(context, "Login Error", "Failed to sign in with Google.");
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        _showAlert(context, "Login Error", "An error occurred during Google sign-in.");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _hasLoginError = false;
    });

    if (email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    
    if (password.length < 6) { 
        setState(() => _hasLoginError = true);
        _showAlert(context, "Login Error", "Incorrect email or password.");
        return;
    }

    setState(() => _isSubmitting = true);

    try {
      final sb.AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
         throw const sb.AuthException('Invalid login credentials.');
      }
      
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/tabs',
        (route) => false, 
        arguments: 0, 
      );

    } on sb.AuthException catch (e) {
      debugPrint("Supabase Login Error: ${e.message}");
      if (mounted) {
        setState(() => _hasLoginError = true);
        _showAlert(context, "Login Error", "Incorrect email or password.");
      }
    } catch (e) {
      debugPrint("Generic Login Error: $e");
      if (mounted) {
        _showAlert(context, "Login Error", "An unexpected network error occurred.");
      }
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(_rikazLogoPath, height: 120, width: 120),
                const SizedBox(height: 16),
                const Text(
                  'Welcome Back to Rikaz',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextDark),
                ),
                const Text(
                  'Log in to continue your journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: secondaryTextGrey),
                ),
                const SizedBox(height: 32),

                // Fixed Google Sign-In Button
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: primaryTextDark),
                  ),
                  label: Text(
                    _isSubmitting ? "Signing in..." : "Continue with Google",
                    style: const TextStyle(color: primaryTextDark, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: secondaryTextGrey.withOpacity(0.3), width: 1),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(child: Divider(color: secondaryTextGrey.withOpacity(0.3))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: secondaryTextGrey, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(child: Divider(color: secondaryTextGrey.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTextInput(
                  controller: _emailController,
                  hintText: "Email",
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  hasError: _hasLoginError, 
                ),
                const SizedBox(height: 12),
                
                _buildTextInput(
                  controller: _passwordController,
                  hintText: "Password",
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  hasError: _hasLoginError,
                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 16),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                       if (!_isSubmitting) Navigator.of(context).pushNamed(_forgotPasswordRoute);
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: primaryThemeColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleLogin, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dfDeepTeal, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    elevation: 5,
                  ),
                  child: Text(
                    _isSubmitting ? "Logging in..." : "Log In", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () {
                    if (!_isSubmitting) Navigator.of(context).pushReplacementNamed(_signupRoute);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text.rich(
                      TextSpan(
                        text: 'Don\'t have an account? ',
                        style: TextStyle(color: secondaryTextGrey, fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(color: primaryThemeColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
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