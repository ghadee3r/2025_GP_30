import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// --- Constants ---
const String _rikazLogoPath = "assets/images/RikazLogo.png";
const String _signupRoute = "/signup";

// Get the Supabase client instance
final supabase = sb.Supabase.instance.client;

// --- Custom Alert Dialog Widget ---
void _showAlert(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text("OK", style: TextStyle(color: Color(0xFF4f46e5))),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Login Logic (Uses Supabase Auth) ---
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    
    if (password.length < 6) { 
        _showAlert(context, "Password Error", "Password must be at least 6 characters long.");
        return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 🚨 SUPABASE SIGN IN LOGIC 🚨
      final sb.AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        // If sign-in fails but no explicit exception is thrown,
        // it often means credentials were bad or email confirmation is pending.
         throw const sb.AuthException('Invalid login credentials or email confirmation required.');
      }
      
      if (!mounted) return;

      _showAlert(context, "Welcome Back!", "Logged in as ${response.user!.email}");
      
      // Navigate on success: AuthWrapper in main.dart will detect the session
      // and redirect to the correct home screen /tabs.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/tabs',
        (route) => false,
        arguments: 0, // 0 = Home tab
      );

    } on sb.AuthException catch (e) {
      debugPrint("Supabase Login Error: ${e.message}");
      if (mounted) {
        _showAlert(context, "Login Error", e.message);
      }
    } catch (e) {
      debugPrint("Generic Login Error: $e");
      if (mounted) {
        _showAlert(context, "Login Error", "An unexpected network or server error occurred.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- Helper widget for consistent input styling ---
  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
    bool obscureText = false,
    bool autocorrect = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: autocorrect,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Logo
                Image.asset(
                  _rikazLogoPath,
                  height: 150,
                  width: 150,
                ),
                const SizedBox(height: 10),

                // Title
                const Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                // Subtitle
                const Text(
                  'Log in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),

                // Email Input
                _buildTextInput(
                  controller: _emailController,
                  hintText: "Email",
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                // Password Input
                _buildTextInput(
                  controller: _passwordController,
                  hintText: "Password",
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),

                // Log In Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleLogin,
                  child: Text(
                    _isSubmitting ? "Logging in..." : "Log In",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Up Link (Navigates to /signup)
                GestureDetector(
                  onTap: () {
                    if (!_isSubmitting) {
                      Navigator.of(context).pushReplacementNamed(_signupRoute);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text(
                      'Don’t have an account? Sign Up',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4f46e5),
                        fontSize: 15,
                      ),
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
