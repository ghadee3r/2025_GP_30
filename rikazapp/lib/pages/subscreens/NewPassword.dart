import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final supabase = sb.Supabase.instance.client;

class NewPassword extends StatefulWidget {
  const NewPassword({super.key});

  @override
  State<NewPassword> createState() => _NewPasswordState();
}

class _NewPasswordState extends State<NewPassword> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _currentUserEmail;
  bool _sessionChecked = false;

  @override
  void initState() {
    super.initState();
    debugPrint("NewPassword screen initialized");
    _checkSessionAndGetEmail();
  }

  void _checkSessionAndGetEmail() async {
    // Wait a bit for the session to be established (in case coming from deep link)
    await Future.delayed(const Duration(milliseconds: 500));
    
    final session = supabase.auth.currentSession;
    debugPrint("Session in NewPassword: ${session != null}");
    
    if (session != null) {
      _currentUserEmail = session.user?.email;
      debugPrint("Current user email: $_currentUserEmail");
    } else {
      debugPrint("No session found - user might need to complete the reset flow");
      // Don't show error immediately - wait to see if session gets established
    }
    
    setState(() {
      _sessionChecked = true;
    });
  }

  void _showErrorDialog(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Color(0xFF4f46e5))),
            ),
          ],
        ),
      );
    });
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false);
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF4f46e5))),
          ),
        ],
      ),
    );
  }

  void _goBackToLogin() {
    // Show confirmation dialog if user has started entering data
    if (_newPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Password Reset?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to cancel? Your password reset progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Reset', style: TextStyle(color: Color(0xFF666666))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
              child: const Text('Cancel Reset', style: TextStyle(color: Color(0xFF4f46e5))),
            ),
          ],
        ),
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _updatePassword() async {
    // Final session check before updating password
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showErrorDialog("Session Error", "No valid session found. Please request a new password reset link and make sure you click the link in your email.");
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Basic validations
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog("Missing Info", "Please fill in both password fields.");
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog("Password Mismatch", "Passwords do not match.");
      return;
    }

    // Updated password validation with specific error messages
    if (newPassword.length < 12) {
      _showErrorDialog("Weak Password", "Password must be at least 12 characters long.");
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(newPassword)) {
      _showErrorDialog("Weak Password", "Password must contain at least one uppercase letter.");
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(newPassword)) {
      _showErrorDialog("Weak Password", "Password must contain at least one lowercase letter.");
      return;
    }
    if (!RegExp(r'\d').hasMatch(newPassword)) {
      _showErrorDialog("Weak Password", "Password must contain at least one number.");
      return;
    }
    // Updated to allow any special character, not just @, &, _
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPassword)) {
      _showErrorDialog("Weak Password", "Password must contain at least one special character (e.g., !@#\$%^&*).");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        if (!mounted) return;
        _showSuccessDialog('Your password has been updated successfully. You can now log in with your new password.');
      }
    } on sb.AuthException catch (e) {
      if (!mounted) return;
      
      if (e.message.contains('password should be different') || 
          e.message.contains('same as old') ||
          e.message.contains('password reuse')) {
        _showErrorDialog("Password Error", "You cannot use the same password as your current one. Please choose a different password.");
      } else {
        _showErrorDialog("Update Error", "Error updating password: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Update Error", "An unexpected error occurred.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF666666),
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking session
    if (!_sessionChecked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4f46e5)),
              SizedBox(height: 20),
              Text(
                'Setting up password reset...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Back button with confirmation
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF4f46e5)),
                  onPressed: _goBackToLogin,
                ),
              ),
              
              const SizedBox(height: 20),

              // Logo
              Image.asset(
                "assets/images/RikazLogo.png",
                height: 120,
                width: 120,
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Create New Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              
              // Subtitle
              Text(
                _currentUserEmail != null 
                  ? 'Enter a new password for $_currentUserEmail'
                  : 'Enter a new, secure password for your account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 32),

              // New Password Field
              _buildTextInput(
                controller: _newPasswordController,
                hintText: "New Password",
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Password Field
              _buildTextInput(
                controller: _confirmPasswordController,
                hintText: "Confirm Password",
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),

              // Password requirements note - UPDATED
              const Padding(
                padding: EdgeInsets.only(top: 16.0, bottom: 24.0),
                child: Text(
                  'Password must be at least 12 characters long and contain:\n• One uppercase letter • One lowercase letter\n• One number • One special character (!@#\$%^&*)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),

              // Update Button
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4f46e5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  _isLoading ? "Updating..." : "Update Password",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Session status message
              if (_currentUserEmail == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Note: Make sure you clicked the reset link from your email to set up your session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),

              // Cancel option
              TextButton(
                onPressed: _goBackToLogin,
                child: const Text(
                  'Cancel and return to login',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
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