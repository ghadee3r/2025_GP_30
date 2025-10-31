import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// --- Constants ---
const String tabsRoute = "/tabs"; // Route to main screen after success

final supabase = sb.Supabase.instance.client;

// --- Alert Helper ---
void showAlert(BuildContext context, String title, String message,
    {VoidCallback? onOK}) {
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
              if (onOK != null) onOK();
            },
          ),
        ],
      );
    },
  );
}

class NewPassword extends StatefulWidget {
  const NewPassword({super.key});

  @override
  State<NewPassword> createState() => NewPasswordState();
}

class NewPasswordState extends State<NewPassword> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Password Strength Validation ---
  bool _isStrongPassword(String password) {
    // At least 8 chars, 1 upper, 1 lower, 1 number, 1 special char
    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.,;:?]).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> handlePasswordUpdate() async {
    final session = sb.Supabase.instance.client.auth.currentSession;
debugPrint("Current session user before update: ${session?.user?.email ?? 'NO SESSION'}");

    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Basic validations
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      showAlert(context, "Missing Info", "Please fill in both password fields.");
      return;
    }

    if (newPassword != confirmPassword) {
      showAlert(context, "Error", "Passwords do not match.");
      return;
    }

    if (!_isStrongPassword(newPassword)) {
      showAlert(
        context,
        "Weak Password",
        "Password must be at least 8 characters long and include:\n"
        "• Uppercase letter\n• Lowercase letter\n• Number\n• Special symbol (!@#\$&*~)",
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final res = await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      if (res.user != null) {
        if (!mounted) return;

        showAlert(
          context,
          "Success!",
          "Your password has been reset. You are now logged in.",
          onOK: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              tabsRoute,
              (route) => false,
              arguments: 0,
            );
          },
        );
      } else {
        throw const sb.AuthException('Failed to update password.');
      }
    } on sb.AuthException catch (e) {
      debugPrint("Supabase Update Error: ${e.message}");
      if (mounted) {
        showAlert(
          context,
          "Update Error",
          "Could not update password. Your reset link may have expired.\n"
          "Please try again from the 'Forgot Password' screen.",
        );
      }
    } catch (e) {
      debugPrint("Generic Update Error: $e");
      if (mounted) {
        showAlert(context, "Error", "An unexpected error occurred.");
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // --- Input builder ---
  Widget buildTextInput({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.visiblePassword,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
      ),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF222222),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Set Your New Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter a strong, new password below.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),

                buildTextInput(
                  controller: newPasswordController,
                  hintText: "New Password",
                  obscureText: true,
                ),
                const SizedBox(height: 12),

                buildTextInput(
                  controller: confirmPasswordController,
                  hintText: "Confirm New Password",
                  obscureText: true,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isSubmitting ? null : handlePasswordUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4f46e5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    isSubmitting ? "Updating..." : "Update Password",
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
