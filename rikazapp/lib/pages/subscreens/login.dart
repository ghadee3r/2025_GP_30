import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// --- Constants ---
const String _rikazLogoPath = "assets/images/RikazLogo.png"; // Path to the app logo asset
const String _signupRoute = "/signup"; // Route name for the Sign Up screen
const String _forgotPasswordRoute = "/forgot-password"; // New route name for the Forgot Password screen

// Get the Supabase client instance, initialized elsewhere in the app (e.g., main.dart)
final supabase = sb.Supabase.instance.client;

// --- Custom Alert Dialog Helper ---
// Displays a custom AlertDialog for showing messages and errors to the user
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
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

// Stateful widget for the main Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for handling input from the email and password text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // State variable to manage the loading/submission status of the button
  bool _isSubmitting = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is removed from the tree
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Login Logic (Uses Supabase Auth) ---
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic form validation checks
    if (email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }
    
    // Simple password length validation
    if (password.length < 6) { 
        _showAlert(context, "Password Error", "Password must be at least 6 characters long.");
        return;
    }

    // Set loading state to true and disable the button
    setState(() {
      _isSubmitting = true;
    });

    try {
      // 🚨 SUPABASE SIGN IN LOGIC 🚨
      // Attempt to sign in the user using the email and password
      final sb.AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Check if a user session was successfully created
      if (response.user == null) {
        // If sign-in fails but no explicit exception is thrown,
        // it often means credentials were bad or email confirmation is pending.
         throw const sb.AuthException('Invalid login credentials or email confirmation required.');
      }
      
      if (!mounted) return;

      // Show success message and user's email
      _showAlert(context, "Welcome Back!", "Logged in as ${response.user!.email}");
      
      // Navigate to the main application screen ('/tabs') and remove all previous routes
      // NOTE: Ensure '/tabs' is defined in your main route table.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/tabs',
        (route) => false, // Remove all routes below the new route
        arguments: 0, // Pass argument (e.g., initial tab index)
      );

    } on sb.AuthException catch (e) {
      // Handle authentication exceptions thrown by Supabase
      debugPrint("Supabase Login Error: ${e.message}");
      if (mounted) {
        // Display a user-friendly error message
        String errorMessage = "Login failed. Check your email and password.";
        if (e.message.contains('Invalid login credentials')) {
          errorMessage = "Incorrect email or password.";
        }
        _showAlert(context, "Login Error", errorMessage);
      }
    } catch (e) {
      // Handle generic errors (e.g., network issues)
      debugPrint("Generic Login Error: $e");
      if (mounted) {
        _showAlert(context, "Login Error", "An unexpected network or server error occurred.");
      }
    } finally {
      // Re-enable the button regardless of success or failure
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
      obscureText: obscureText, // Hides input for password fields
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
                  height: 120,
                  width: 120,
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Welcome Back to Rikaz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                // Subtitle
                const Text(
                  'Log in to continue your journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input field
                _buildTextInput(
                  controller: _emailController,
                  hintText: "Email",
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                // Password Input field
                _buildTextInput(
                  controller: _passwordController,
                  hintText: "Password",
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                
                // --- FORGOT PASSWORD LINK ---
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                       if (!_isSubmitting) {
                          // Navigate to the dedicated Forgot Password screen
                          Navigator.of(context).pushNamed(_forgotPasswordRoute);
                       }
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF4f46e5), // Primary accent color
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Log In Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleLogin, // Disable if submitting
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4f46e5), // Primary button color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    _isSubmitting ? "Logging in..." : "Log In", // Change text when loading
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Up Link (Navigates to /signup)
                GestureDetector(
                  onTap: () {
                    if (!_isSubmitting) {
                      // Navigate to Sign Up screen and replace the current login route
                      Navigator.of(context).pushReplacementNamed(_signupRoute);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text.rich(
                      TextSpan(
                        text: 'Don’t have an account? ',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
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
      ),
    );
  }
}