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

  @override
  void initState() {
    super.initState();
    debugPrint("NewPassword screen initialized");
    _checkSession();
    _getCurrentUserEmail();
  }

  void _checkSession() {
    final session = supabase.auth.currentSession;
    debugPrint("Session in NewPassword: ${session != null}");
    if (session == null) {
      _showErrorDialog("No valid session found. Please request a new password reset link.");
    }
  }

  void _getCurrentUserEmail() {
    final session = supabase.auth.currentSession;
    _currentUserEmail = session?.user?.email;
    debugPrint("Current user email: $_currentUserEmail");
  }

  void _showErrorDialog(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Check if the new password is different from the old password
  Future<bool> _isPasswordDifferent(String newPassword) async {
    try {
      // Try to sign in with the new password to see if it's the same as old password
      // This is a workaround since Supabase doesn't provide direct old password check in recovery flow
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null && _currentUserEmail != null) {
        // We can't directly check old password in recovery flow, so we'll rely on client-side validation
        // and show a message encouraging users to use a different password
        debugPrint("Password change requested for: $_currentUserEmail");
        
        // In a real implementation, you might want to store the last password change timestamp
        // and warn users if they're reusing recent passwords
        return true; // For now, we'll handle this in the UI validation
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Basic validations
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog("Please fill in both password fields.");
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog("Passwords do not match.");
      return;
    }

    if (newPassword.length < 6) {
      _showErrorDialog("Password must be at least 6 characters long.");
      return;
    }

    // Check for common weak passwords
    if (_isCommonPassword(newPassword)) {
      _showErrorDialog("This password is too common. Please choose a more unique password.");
      return;
    }

    // Check if password contains user email
    if (_currentUserEmail != null && _containsEmail(newPassword, _currentUserEmail!)) {
      _showErrorDialog("Password should not contain your email address.");
      return;
    }

    // Additional password strength checks
    final passwordStrength = _checkPasswordStrength(newPassword);
    if (!passwordStrength.isStrong) {
      _showErrorDialog(passwordStrength.message);
      return;
    }

    // Warn user if they might be using the same password
    final mightBeSamePassword = _mightBeSameOldPassword(newPassword);
    if (mightBeSamePassword) {
      final shouldContinue = await _showSamePasswordWarning();
      if (!shouldContinue) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        if (!mounted) return;
        _showSuccessDialog('Your password has been updated successfully.');
      }
    } on sb.AuthException catch (e) {
      if (!mounted) return;
      
      if (e.message.contains('password should be different') || 
          e.message.contains('same as old') ||
          e.message.contains('password reuse')) {
        _showErrorDialog("You cannot use the same password as your current one. Please choose a different password.");
      } else {
        _showErrorDialog("Error updating password: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("An unexpected error occurred.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isCommonPassword(String password) {
    final commonPasswords = [
      'password', '123456', '12345678', '123456789', '12345',
      'qwerty', 'abc123', 'password1', '1234567', 'admin',
      'welcome', 'monkey', '1234567890', '000000', '123123'
    ];
    return commonPasswords.contains(password.toLowerCase());
  }

  bool _containsEmail(String password, String email) {
    final emailLocalPart = email.split('@').first.toLowerCase();
    return password.toLowerCase().contains(emailLocalPart);
  }

  PasswordStrength _checkPasswordStrength(String password) {
    if (password.length < 8) {
      return PasswordStrength(
        isStrong: false,
        message: "Password should be at least 8 characters long."
      );
    }

    bool hasUpper = false;
    bool hasLower = false;
    bool hasDigit = false;
    bool hasSpecial = false;

    for (var char in password.runes) {
      if (char >= 65 && char <= 90) hasUpper = true; // A-Z
      if (char >= 97 && char <= 122) hasLower = true; // a-z
      if (char >= 48 && char <= 57) hasDigit = true; // 0-9
      if ((char >= 33 && char <= 47) || 
          (char >= 58 && char <= 64) ||
          (char >= 91 && char <= 96) ||
          (char >= 123 && char <= 126)) hasSpecial = true; // special chars
    }

    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      return PasswordStrength(
        isStrong: false,
        message: "Password should include uppercase letters, lowercase letters, numbers, and special characters."
      );
    }

    return PasswordStrength(isStrong: true, message: "");
  }

  bool _mightBeSameOldPassword(String newPassword) {
    // Simple heuristic: if password is very simple/short, it might be the old one
    // You can enhance this with more sophisticated checks
    return newPassword.length < 8 || _isCommonPassword(newPassword);
  }

  Future<bool> _showSamePasswordWarning() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Password Warning'),
        content: const Text(
          'This password looks similar to commonly used passwords. '
          'For security reasons, we recommend using a completely new password '
          'that you haven\'t used before.\n\n'
          'Do you want to continue with this password?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Choose Different'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set New Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create New Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a new, secure password that you haven\'t used before.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            // New Password Field
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Confirm Password Field
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
            
            // Password requirements
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password must contain:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• At least 8 characters\n'
                    '• Uppercase & lowercase letters\n'
                    '• Number & special characters\n'
                    '• Different from your previous password',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Update Button
            ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4f46e5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 178, 203, 226)),
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordStrength {
  final bool isStrong;
  final String message;

  PasswordStrength({required this.isStrong, required this.message});
}