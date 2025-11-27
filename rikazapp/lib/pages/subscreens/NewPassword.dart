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

  // UX State for validation errors
  bool _passwordHasError = false;
  bool _confirmPasswordHasError = false;
  String _validationErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSessionAndGetEmail();
  }

  void _checkSessionAndGetEmail() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final session = supabase.auth.currentSession;
    
    if (session != null) {
      _currentUserEmail = session.user?.email;
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
          backgroundColor: cardBackground,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark)),
          content: Text(message, style: const TextStyle(color: primaryTextDark)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: dfDeepTeal)),
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
        backgroundColor: cardBackground,
        title: const Text('Success', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark)),
        content: Text(message, style: const TextStyle(color: primaryTextDark)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false);
            },
            child: const Text("OK", style: TextStyle(color: dfDeepTeal)),
          ),
        ],
      ),
    );
  }

  void _goBackToLogin() {
    if (_newPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: cardBackground,
          title: const Text('Cancel Reset?', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark)),
          content: const Text('Are you sure you want to cancel? Your progress will be lost.', style: TextStyle(color: primaryTextDark)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue', style: TextStyle(color: secondaryTextGrey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
              child: const Text('Cancel', style: TextStyle(color: dfDeepTeal)),
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

  // Helper to validate password
  String? _validatePasswordRequirements(String password) {
    if (password.length < 12) return "Must be at least 12 characters.";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Must contain an uppercase letter.";
    if (!RegExp(r'[a-z]').hasMatch(password)) return "Must contain a lowercase letter.";
    if (!RegExp(r'\d').hasMatch(password)) return "Must contain a number.";
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return "Must contain a special character.";
    return null; 
  }

  Future<void> _updatePassword() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showErrorDialog("Session Error", "No valid session found. Please request a new link.");
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Reset errors
    setState(() {
      _passwordHasError = false;
      _confirmPasswordHasError = false;
      _validationErrorMessage = '';
    });

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog("Missing Info", "Please fill in both password fields.");
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _passwordHasError = true;
        _confirmPasswordHasError = true;
        _validationErrorMessage = "Passwords do not match.";
      });
      return;
    }

    // Check requirements
    String? requirementError = _validatePasswordRequirements(newPassword);
    if (requirementError != null) {
      setState(() {
        _passwordHasError = true;
        _validationErrorMessage = requirementError;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        if (!mounted) return;
        _showSuccessDialog('Your password has been updated successfully. You will be logged into your account.');
      }
    } on sb.AuthException catch (e) {
      if (!mounted) return;
      
      if (e.message.contains('password should be different') || 
          e.message.contains('same as old')) {
        _showErrorDialog("Password Error", "Please choose a different password from your current one.");
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
    bool hasError = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      cursorColor: dfDeepTeal,
      style: const TextStyle(fontSize: 16, color: primaryTextDark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: secondaryTextGrey),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: hasError ? errorIndicatorRed : secondaryTextGrey,
            width: hasError ? 2.0 : 1.0,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: hasError ? errorIndicatorRed : dfDeepTeal,
            width: 2,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: hasError ? errorIndicatorRed : secondaryTextGrey,
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
    if (!_sessionChecked) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: dfDeepTeal),
              SizedBox(height: 20),
              Text(
                'Setting up password reset...',
                style: TextStyle(fontSize: 16, color: secondaryTextGrey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: dfDeepTeal),
                  onPressed: _goBackToLogin,
                ),
              ),
              
              const SizedBox(height: 20),

              Image.asset(
                "assets/images/RikazLogo.png",
                height: 120,
                width: 120,
              ),
              const SizedBox(height: 16),

              const Text(
                'Create New Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
              
              Text(
                _currentUserEmail != null 
                  ? 'Enter a new password for $_currentUserEmail'
                  : 'Enter a new, secure password for your account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: secondaryTextGrey,
                ),
              ),
              const SizedBox(height: 32),

              _buildTextInput(
                controller: _newPasswordController,
                hintText: "New Password",
                obscureText: _obscureNewPassword,
                hasError: _passwordHasError,
                onToggleVisibility: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              const SizedBox(height: 16),
              
              _buildTextInput(
                controller: _confirmPasswordController,
                hintText: "Confirm Password",
                obscureText: _obscureConfirmPassword,
                hasError: _confirmPasswordHasError,
                onToggleVisibility: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),

              if (_validationErrorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: errorIndicatorRed, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _validationErrorMessage,
                          style: const TextStyle(fontSize: 12, color: errorIndicatorRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dfDeepTeal,
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

              if (_currentUserEmail == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Note: Make sure you clicked the reset link from your email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
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