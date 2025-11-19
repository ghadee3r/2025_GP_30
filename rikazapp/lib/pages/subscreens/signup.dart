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
  // Controller for confirming the password
  final TextEditingController _confirmPasswordController = TextEditingController(); 

  // State to hold the post-signup success/error message
  String _postSignupMessage = ''; 
  // State to control the message color (true for green, false for red)
  bool _isSuccessMessage = true; 

  bool _isSubmitting = false;

  // State to manage password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    //  Dispose the new controller
    _confirmPasswordController.dispose();
    super.dispose();
  }

// SUPABASE SIGN UP LOGIC WITH ON-SCREEN ERROR
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    //  Get the confirmed password
    final confirmPassword = _confirmPasswordController.text;

    // --- Validation Checks ---
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showAlert(context, "Invalid Email", "Please enter a valid email address.");
      return;
    }
    
    // ➕ NEW: Check if passwords match
    if (password != confirmPassword) {
      _showAlert(context, "Password Mismatch", "Passwords do not match.");
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
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      _showAlert(context, "Weak Password", "Password must contain at least one special character (e.g., !@#\$%^&*).");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _postSignupMessage = ''; // Clear previous messages
    });

    try {
      // Attempt to sign up
      final sb.AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: 'rikazapp://login', 
      );

      if (!mounted) return;
      
      // --- START OF NEW "IDENTITIES" LOGIC ---

      // Check if the user object and identities list exist.
      // A fake user object (for an existing user) will have response.user.identities as an empty list [].
      // A real new user will have one identity in the list.
      if (response.user != null && (response.user!.identities == null || response.user!.identities!.isEmpty)) {
        
        // --- CASE 1: USER ALREADY EXISTS ---
        // Supabase returned a fake user with no identities.
        setState(() {
          _postSignupMessage = "This email is already registered. Please log in instead.";
          _isSuccessMessage = false; // This is an "error" for the signup form
        });

      } else if (response.user != null) {
        
        // --- CASE 2: USER IS NEW ---
        // We got a user AND they have an identity. Send the verification email.
        setState(() {
          _postSignupMessage = 'A verification email has been sent to $email. Please click the link to confirm your account, then log in.';
          _isSuccessMessage = true;
          // Clear password fields on successful sign up
          _passwordController.clear();
          _confirmPasswordController.clear();
        });

      } else {
        // Fallback for any other unexpected null response
        setState(() {
          _postSignupMessage = 'An error occurred. Please try again.';
          _isSuccessMessage = false;
        });
      }
      // --- END OF VERIFICATION LOGIC ---
      
    } on sb.AuthException catch (e) { 
      if (!mounted) return;
      
      // This catch block is still a good fallback
      String errorMessage = e.message;
      if (errorMessage.contains('User already registered') || 
          errorMessage.contains('already has an account')) {
         
        setState(() {
          _postSignupMessage = "This email is in use. Please log in.";
          _isSuccessMessage = false;
        });
         
      } else {
         _showAlert(context, "Signup Error", errorMessage);
      }
      
    } catch (e) {
      if (!mounted) return;
      _showAlert(context, "Signup Error", "An unexpected error occurred: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // included obscureText and onToggleVisibility
  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
    bool obscureText = false,
    bool autocorrect = true,
    // ➕ NEW: Parameters for visibility toggle
    VoidCallback? onToggleVisibility, 
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
        // ➕ NEW: Add the suffix icon for visibility toggle if the callback is provided
        suffixIcon: onToggleVisibility != null ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF666666),
          ),
          onPressed: onToggleVisibility,
        ) : null,
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

              // Full Name
              _buildTextInput(
                controller: _nameController,
                hintText: "Full Name",
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              
              // Email
              _buildTextInput(
                controller: _emailController,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              
              // Password use visibility toggle
              _buildTextInput(
                controller: _passwordController,
                hintText: "Password",
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscurePassword,
                autocorrect: false,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: 12),
              
              // Confirm Password
              _buildTextInput(
                controller: _confirmPasswordController,
                hintText: "Confirm Password",
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscureConfirmPassword,
                autocorrect: false,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),

              // Password requirements note
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
                child: Text(
                  _isSubmitting ? "Creating..." : "Sign Up",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
                  child: Text(
                    'Already have an account? Log in',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF4f46e5), fontSize: 15),
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