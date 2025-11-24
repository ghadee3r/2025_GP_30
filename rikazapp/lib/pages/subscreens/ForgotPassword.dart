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

// --- Constants ---
const String loginRoute = "/login"; 
final supabase = sb.Supabase.instance.client;
const String supabaseRedirectUrl = 'io.rikaz.app://reset-password'; 

// --- Custom Alert Dialog Helper ---
void showAlert(BuildContext context, String title, String message, {VoidCallback? onOK}) {
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
              if (onOK != null) {
                onOK(); 
              }
            },
          ),
        ],
      );
    },
  );
}

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => ForgotPasswordState();
}

class ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  bool isSubmitting = false; 

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

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
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseRedirectUrl, 
      );
      
      if (!mounted) return;

      showAlert(
        context, 
        "Check Your Email", 
        "If an account is associated with $email, a password reset link has been sent. Please check your spam folder.",
        onOK: () {
          Navigator.of(context).pushReplacementNamed(loginRoute);
        }
      );

    } on sb.AuthException catch (e) {
      final message = e.message;
      debugPrint("Supabase Reset Error: $message");

      if (message.contains("For security purposes")) {
        final secondsMatch = RegExp(r'(\d+)\s*seconds?').firstMatch(message);
        final seconds = secondsMatch != null ? secondsMatch.group(1) ?? "a few" : "a few";

        showAlert(
          context,
          "Please Wait",
          "You can only request another password reset after $seconds seconds.\n\nTry again shortly.",
        );
      } else {
        showAlert(
          context,
          "Request Error",
          "Could not send the reset link. Please verify your email or try again later.",
        );
      }
    } catch (e) {
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

  Widget buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: primaryThemeColor,
      style: const TextStyle(fontSize: 16, color: primaryTextDark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: secondaryTextGrey),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primaryThemeColor, width: 2),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: secondaryTextGrey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: primaryBackground,
        elevation: 0,
        foregroundColor: primaryTextDark,
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
                    color: primaryTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we will send you a link to reset your password.',
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryTextGrey,
                  ),
                ),
                const SizedBox(height: 32),

                buildTextInput(
                  controller: emailController,
                  hintText: "Email Address",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isSubmitting ? null : handlePasswordReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryThemeColor,
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