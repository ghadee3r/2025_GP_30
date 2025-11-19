import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// --- Constants ---
const String loginRoute = "/login"; // Route to navigate back to the login screen

// Get the Supabase client instance, assumed to be initialized globally
final supabase = sb.Supabase.instance.client;

// Deep Link for Supabase to redirect back to the app after clicking the email link.
// IMPORTANT: This URL must be configured in your Supabase Auth settings 
// and your native Flutter project (iOS/Android) for Deep Linking to work.
const String supabaseRedirectUrl = 'io.rikaz.app://reset-password'; 

// --- Custom Alert Dialog Helper ---
// Displays a custom AlertDialog and optionally executes a callback on 'OK'
void showAlert(BuildContext context, String title, String message, {VoidCallback? onOK}) {
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
              if (onOK != null) {
                onOK(); // Execute optional action, like navigation
              }
            },
          ),
        ],
      );
    },
  );
}

// Widget for the Forgot Password Page
class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => ForgotPasswordState();
}

class ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  bool isSubmitting = false; // State to handle button loading animation

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // --- Supabase Reset Password Logic ---
  Future<void> handlePasswordReset() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showAlert(context, "Missing Info", "Please enter your email address.");
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // SUPABASE RESET PASSWORD REQUEST
      // This sends the email with the reset link.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseRedirectUrl, // Redirects the user back to the app via deep link
      );
      
      if (!mounted) return;

      // SUCCESS: Show a generic message to prevent malicious actors from guessing emails
      showAlert(
        context, 
        "Check Your Email", 
        "If an account is associated with $email, a password reset link has been sent. Please check your spam folder.",
        onOK: () {
           // Navigate back to login after showing success message
          Navigator.of(context).pushReplacementNamed(loginRoute);
        }
      );

    } on sb.AuthException catch (e) {
      final message = e.message;
      debugPrint("Supabase Reset Error: $message");

      // Detect Supabase rate-limit message
      if (message.contains("For security purposes")) {
        // Extract the remaining seconds (if present)
        final secondsMatch = RegExp(r'(\d+)\s*seconds?').firstMatch(message);
        final seconds =
            secondsMatch != null ? secondsMatch.group(1) ?? "a few" : "a few";

        showAlert(
          context,
          "Please Wait",
          "You can only request another password reset after $seconds seconds.\n\nTry again shortly.",
        );
      } else {
        // Other auth-related errors
        showAlert(
          context,
          "Request Error",
          "Could not send the reset link. Please verify your email or try again later.",
        );
      }
    } catch (e) {
      // Handle generic errors
      debugPrint("Generic Reset Error: $e");
      if (mounted) {
        showAlert(context, "Request Error", "An unexpected error occurred.");
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // --- Helper widget for consistent input styling (reused from login) ---
  Widget buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
      ),
    );
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF222222),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Trouble logging in?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we will send you a link to reset your password.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input
                buildTextInput(
                  controller: emailController,
                  hintText: "Email Address",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                // Send Reset Link Button
                ElevatedButton(
                  onPressed: isSubmitting ? null : handlePasswordReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4f46e5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    isSubmitting ? "Sending Link..." : "Send Reset Link",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
