import 'package:flutter/material.dart';
// Standard Dart package for JSON encoding/decoding
import 'dart:convert';
// Package for making API calls. You must add 'http: ^latest_version' to your pubspec.yaml
import 'package:http/http.dart' as http;
// Package for local persistence (replacement for AsyncStorage). You must add 'shared_preferences: ^latest_version' to your pubspec.yaml
import 'package:shared_preferences/shared_preferences.dart';

// --- Constants (Replacing JS variables) ---
// IMPORTANT: You must update your pubspec.yaml to include the http and shared_preferences packages.
// IMPORTANT: Update your IP address if it changes.
const String _apiBaseUrl = "http://192.168.100.15:8000/api";
// This asset path must be added to your Flutter project's pubspec.yaml under 'assets:'
const String _rikazLogoPath = "assets/images/RikazLogo.png"; 
const String _googleIconUrl = "https://developers.google.com/identity/images/g-logo.png";
// Placeholder route names for navigation (use your actual Flutter route names)
const String _loginRoute = "/login";
const String _tabsRoute = "/tabs";
const String _homeRoute = "/home"; // Added home route constant

// --- Custom Alert Dialog Widget (Replacement for Alert.alert) ---
// In Flutter, alerts are shown via showDialog
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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // --- State and Controller Variables (Replacing React's useState) ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  
  // Mock flag for Google Auth readiness, as the actual setup requires packages
  bool _isGoogleAuthReady = true; 

  @override
  void dispose() {
    // Dispose of controllers to free up memory
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Signup Logic (Replacing handleSignup) ---
  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showAlert(context, "Missing Info", "Please fill in all fields.");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = Uri.parse('$_apiBaseUrl/register');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || data['success'] == false) {
        // Dart throws an exception for non-200 status or custom failure flag
        throw Exception(data['message'] ?? "Registration failed.");
      }

      // Implementation of AsyncStorage replacement: Use shared_preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userSession', jsonEncode({'email': email}));

      if (mounted) {
        _showAlert(context, "Account Created", "Welcome, $name!");
        // Replacement for router.replace: Navigating using Flutter Navigator
        // Successful sign up leads to the main tabs view
        Navigator.of(context).pushReplacementNamed(_tabsRoute);
      }

    } catch (e) {
      debugPrint("Signup Error: $e");
      if (mounted) {
        final errorMessage = e.toString().contains("Exception:") ? e.toString().replaceFirst("Exception: ", "") : "An unexpected error occurred.";
        _showAlert(context, "Signup Error", errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- Google Connect Logic (Replacing promptAsync) ---
  void _handleGoogleConnect() {
    // In a real Flutter app, you would use the 'google_sign_in' package
    // or 'flutter_appauth' for the full OAuth flow.
    debugPrint("Initiating Google Sign-In flow...");
    _showAlert(context, "Feature Placeholder", 
      "Google Sign-In requires the 'google_sign_in' Flutter package and specific native setup. This is currently a mock.");
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
        // Matches React Native's padding
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFcccccc)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFcccccc)),
        ),
        // Focused border color is the primary blue
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4f46e5), width: 2),
        ),
      ),
    );
  }

  // --- UI Build (Replacement for React's return block) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // SingleChildScrollView handles keyboard avoidance and content overflow
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
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 24),

                // Input Fields
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
                  obscureText: true, // secureTextEntry equivalent
                  autocorrect: false,
                ),
                const SizedBox(height: 16),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4f46e5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isSubmitting ? "Creating..." : "Sign Up",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Or Text
                const Text(
                  'or',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF666666), fontSize: 16),
                ),
                const SizedBox(height: 10),

                // Google Button
                OutlinedButton(
                  onPressed: (_isSubmitting || !_isGoogleAuthReady) ? null : _handleGoogleConnect,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFFcccccc), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      // Image.network is used for the Google icon URL
                      Image.network(
                        _googleIconUrl,
                        width: 22,
                        height: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connect Google Calendar',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Log In Link
                GestureDetector(
                  // Pressable/TouchableOpacity equivalent
                  onTap: () {
                    if (!_isSubmitting) {
                      Navigator.of(context).pushReplacementNamed(_loginRoute);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text(
                      'Already have an account? Log in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4f46e5),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                
                // --- START: Skip Button for Testing ---
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    if (!_isSubmitting) {
                      // Navigate directly to the main app screen -> NOW /home
                      Navigator.of(context).pushReplacementNamed(_homeRoute);
                    }
                  },
                  child: const Text(
                    'Skip for now (No DB)',
                    style: TextStyle(
                      color: Color(0xFF9ca3af), // A light gray color
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                // --- END: Skip Button for Testing ---

              ],
            ),
          ),
        ),
      ),
    );
  }
}
