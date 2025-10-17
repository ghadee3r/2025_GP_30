import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ========= Constants =========
const String _rikazLogoPath = "assets/images/RikazLogo.png";
// Get the Supabase client instance using the alias 'sb'
final supabase = sb.Supabase.instance.client;

// ========= Helpers =========

// Basic email format check: e.g., 'user@domain.com'
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

// Password complexity check:
// - At least 8 characters long
// - Contains at least one uppercase letter (A-Z)
// - Contains at least one lowercase letter (a-z)
// - Contains at least one number (0-9)
final RegExp _passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');


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

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🚨 SUPABASE SIGN UP LOGIC WITH VALIDATION 🚨
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    
    // 1. Email Validation Check
    if (!_emailRegex.hasMatch(email)) {
      _showAlert(context, "Invalid Email", "Please enter a valid email address.");
      return;
    }
    
    // 2. Password Complexity Check (Enhanced for 8+ chars, uppercase, lowercase, and number)
    if (!_passwordRegex.hasMatch(password)) {
      _showAlert(
        context,
        "Weak Password",
        "Password must be at least 8 characters long and contain:\n"
        "• One uppercase letter\n"
        "• One lowercase letter\n"
        "• One number",
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final sb.AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );

      if (response.user == null) {
        // This case usually happens if email confirmation is enabled on Supabase
        throw const sb.AuthException('Registration requires email confirmation. Please check your inbox.');
      }

      if (!mounted) return;

      _showAlert(context, "Account Created", "Welcome, $name! Logging you in...");

      // After successful signup and session creation → navigate to Tabs 
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/tabs',
        (route) => false,
        arguments: 0, // 0 = Home tab
      );
    } on sb.AuthException catch (e) { 
      if (!mounted) return;
      _showAlert(context, "Signup Error", e.message);
    } catch (e) {
      if (!mounted) return;
      _showAlert(context, "Signup Error", "An unexpected error occurred: ${e.toString()}");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Logo
              Image.asset(_rikazLogoPath, height: 150, width: 150),
              const SizedBox(height: 10),

              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
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
              ),
              const SizedBox(height: 12),
              _buildTextInput(
                controller: _passwordController,
                hintText: "Password",
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                autocorrect: false,
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSignup,
                child: Text(
                  _isSubmitting ? "Creating..." : "Sign Up",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),

              // Log In link
              GestureDetector(
                onTap: _isSubmitting ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Text(
                    'Already have an account? Log in',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF4f46e5), fontSize: 15),
                  ),
                ),
              ),

              // NOTE: The 'Skip for now (No DB)' link has been removed as requested.
              
            ],
          ),
        ),
      ),
    );
  }
}
