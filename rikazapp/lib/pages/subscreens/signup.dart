import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ========= Constants =========
const String _rikazLogoPath = "assets/images/RikazLogo.png";
// Get the Supabase client instance using the alias 'sb'
final supabase = sb.Supabase.instance.client;

// ========= Helpers =========

// Basic email format check: e.g., 'user@domain.com'
final RegExp _emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

// Updated Password complexity check for 12 characters with all requirements
final RegExp _passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{12,}$');


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

  // State to hold the post-signup success/error message
  String _postSignupMessage = ''; 
  // State to control the message color (true for green, false for red)
  bool _isSuccessMessage = true; 

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🚨 SUPABASE SIGN UP LOGIC WITH ON-SCREEN ERROR 🚨
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // --- Validation Checks ---
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showAlert(context, "Invalid Email", "Please enter a valid email address.");
      return;
    }
    
    // Updated password validation with specific error messages
    if (password.length < 12) {
      _showAlert(context, "Weak Password", "Password must be at least 12 characters long.");
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showAlert(context, "Weak Password", "Password must contain at least one uppercase letter.");
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      _showAlert(context, "Weak Password", "Password must contain at least one lowercase letter.");
      return;
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      _showAlert(context, "Weak Password", "Password must contain at least one number.");
      return;
    }
    // Updated to allow any special character, not just @, &, _
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      _showAlert(context, "Weak Password", "Password must contain at least one special character (e.g., !@#\$%^&*).");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _postSignupMessage = ''; // Clear previous messages
    });

    try {
      // Attempt to sign up - Supabase handles user existence internally
      final sb.AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: 'rikazapp://login', 
      );

      if (!mounted) return;
      
      // Since Supabase doesn't provide a reliable way to distinguish between
      // new and existing users during signup, we'll use a simple approach:
      // Always show the verification message, but make it clear what happened
      
      if (response.user != null) {
        setState(() {
          _postSignupMessage = 'A verification email has been sent to $email. Please click the link to confirm your account, then log in.\n\nIf you already have an account, please check your email for the verification link or use the login page.';
          _isSuccessMessage = true;
        });
      }
      
    } on sb.AuthException catch (e) { 
      if (!mounted) return;
      
      String errorMessage = e.message;
      
      // Handle any auth errors that might indicate user exists
      if (errorMessage.contains('User already registered') || 
          errorMessage.contains('already has an account') ||
          errorMessage.contains('user_already_exists') ||
          errorMessage.contains('email_taken') ||
          errorMessage.contains('already in use')) {
         
        setState(() {
          _postSignupMessage = "This email is already registered. Please log in instead.";
          _isSuccessMessage = false;
        });
         
      } else {
         // Use the standard alert for all other errors
         _showAlert(context, "Signup Error", errorMessage);
      }
      
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6), // Light gray background for input
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
              Image.asset(_rikazLogoPath, height: 120, width: 120),
              const SizedBox(height: 16),

              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
              ),
              const Text(
                'Join Rikaz to start your journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
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
              
              // Password requirements note - UPDATED
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  'Password must be at least 12 characters long and contain:\n• One uppercase letter • One lowercase letter\n• One number • One special character (!@#\$%^&*)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4f46e5), // Primary button color
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  _isSubmitting ? "Creating..." : "Sign Up",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // Conditional message for successful signup or error
              if (_postSignupMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _postSignupMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      // Green for success, Red for error based on the state variable
                      color: _isSuccessMessage ? Colors.green.shade700 : Colors.red.shade700, 
                    ),
                  ),
                ),
                
              // Log In link
              GestureDetector(
                onTap: _isSubmitting ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: Color(0xFF4f46e5), // Highlighted link text
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}